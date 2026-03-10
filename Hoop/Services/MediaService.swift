import AppKit
import Observation

// MARK: - Protocol

enum PlaybackState {
    case playing
    case paused
    case stopped
    case unknown
}

struct NowPlayingInfo {
    var title: String?
    var artist: String?
    var albumArt: NSImage?
    var playbackState: PlaybackState
    var appBundleID: String?
    var duration: TimeInterval?
    var elapsedTime: TimeInterval?
}

protocol MediaServiceProtocol {
    var nowPlaying: NowPlayingInfo { get }
    var isAvailable: Bool { get }

    func playPause()
    func nextTrack()
    func previousTrack()
    func startObserving()
    func stopObserving()
}

// MARK: - MediaRemote Function Types

private typealias MRMediaRemoteGetNowPlayingInfoFunc = @convention(c) (
    DispatchQueue,
    @escaping ([String: Any]) -> Void
) -> Void

private typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunc = @convention(c) (
    DispatchQueue,
    @escaping (Bool) -> Void
) -> Void

private typealias MRMediaRemoteSendCommandFunc = @convention(c) (
    UInt32, UnsafeMutableRawPointer?
) -> Bool

private typealias MRMediaRemoteRegisterForNowPlayingNotificationsFunc = @convention(c) (
    DispatchQueue
) -> Void

private typealias MRMediaRemoteUnregisterForNowPlayingNotificationsFunc = @convention(c) () -> Void

private typealias MRMediaRemoteGetNowPlayingClientFunc = @convention(c) (
    DispatchQueue,
    @escaping (AnyObject?) -> Void
) -> Void

// MARK: - MediaRemote Commands

private enum MRCommand: UInt32 {
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

// MARK: - MediaRemote Info Keys

private enum MRInfoKey {
    static let title = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
    static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
}

// MARK: - MediaRemote Notification Names

private enum MRNotification {
    static let nowPlayingInfoDidChange = "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    static let nowPlayingApplicationIsPlayingDidChange = "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
    static let nowPlayingApplicationDidChange = "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
}

// MARK: - MediaRemote Loader

private final class MediaRemoteLoader {
    static let shared = MediaRemoteLoader()

    let handle: UnsafeMutableRawPointer?

    let getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunc?
    let getIsPlaying: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunc?
    let sendCommand: MRMediaRemoteSendCommandFunc?
    let registerForNotifications: MRMediaRemoteRegisterForNowPlayingNotificationsFunc?
    let unregisterForNotifications: MRMediaRemoteUnregisterForNowPlayingNotificationsFunc?
    let getNowPlayingClient: MRMediaRemoteGetNowPlayingClientFunc?

    var isLoaded: Bool { handle != nil }

    private init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        handle = dlopen(path, RTLD_LAZY)

        guard handle != nil else {
            getNowPlayingInfo = nil
            getIsPlaying = nil
            sendCommand = nil
            registerForNotifications = nil
            unregisterForNotifications = nil
            getNowPlayingClient = nil
            return
        }

        getNowPlayingInfo = Self.loadFunc(handle!, "MRMediaRemoteGetNowPlayingInfo")
        getIsPlaying = Self.loadFunc(handle!, "MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        sendCommand = Self.loadFunc(handle!, "MRMediaRemoteSendCommand")
        registerForNotifications = Self.loadFunc(handle!, "MRMediaRemoteRegisterForNowPlayingNotifications")
        unregisterForNotifications = Self.loadFunc(handle!, "MRMediaRemoteUnregisterForNowPlayingNotifications")
        getNowPlayingClient = Self.loadFunc(handle!, "MRMediaRemoteGetNowPlayingClient")
    }

    private static func loadFunc<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    deinit {
        if let handle { dlclose(handle) }
    }
}

// MARK: - MediaRemoteService

@Observable
final class MediaService: MediaServiceProtocol {

    var nowPlaying = NowPlayingInfo(playbackState: .unknown)

    /// Cached source app icon, updated when appBundleID changes. Avoids expensive NSWorkspace lookups per render.
    var sourceAppIcon: NSImage?

    var isAvailable: Bool { MediaRemoteLoader.shared.isLoaded }

    private var isObserving = false
    private let loader = MediaRemoteLoader.shared
    private var lastIconBundleID: String?

    // MARK: - Commands

    func playPause() {
        sendCommand(.togglePlayPause)
    }

    func nextTrack() {
        sendCommand(.nextTrack)
    }

    func previousTrack() {
        sendCommand(.previousTrack)
    }

    private func sendCommand(_ command: MRCommand) {
        _ = loader.sendCommand?(command.rawValue, nil)
    }

    // MARK: - Observation

    func startObserving() {
        guard !isObserving, loader.isLoaded else { return }
        isObserving = true

        loader.registerForNotifications?(DispatchQueue.main)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleNowPlayingInfoChange),
                       name: Notification.Name(MRNotification.nowPlayingInfoDidChange), object: nil)
        nc.addObserver(self, selector: #selector(handlePlaybackStateChange),
                       name: Notification.Name(MRNotification.nowPlayingApplicationIsPlayingDidChange), object: nil)
        nc.addObserver(self, selector: #selector(handleAppChange),
                       name: Notification.Name(MRNotification.nowPlayingApplicationDidChange), object: nil)

        // Fetch initial state
        refreshNowPlaying()
        refreshPlaybackState()
        refreshNowPlayingApp()
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        loader.unregisterForNotifications?()

        let nc = NotificationCenter.default
        nc.removeObserver(self, name: Notification.Name(MRNotification.nowPlayingInfoDidChange), object: nil)
        nc.removeObserver(self, name: Notification.Name(MRNotification.nowPlayingApplicationIsPlayingDidChange), object: nil)
        nc.removeObserver(self, name: Notification.Name(MRNotification.nowPlayingApplicationDidChange), object: nil)
    }

    // MARK: - Notification Handlers

    @objc private func handleNowPlayingInfoChange() {
        refreshNowPlaying()
    }

    @objc private func handlePlaybackStateChange() {
        refreshPlaybackState()
    }

    @objc private func handleAppChange() {
        refreshNowPlayingApp()
        refreshNowPlaying()
    }

    // MARK: - Data Fetching

    private func refreshNowPlaying() {
        loader.getNowPlayingInfo?(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            self.nowPlaying.title = info[MRInfoKey.title] as? String
            self.nowPlaying.artist = info[MRInfoKey.artist] as? String
            self.nowPlaying.duration = info[MRInfoKey.duration] as? TimeInterval
            self.nowPlaying.elapsedTime = info[MRInfoKey.elapsedTime] as? TimeInterval

            if let artData = info[MRInfoKey.artworkData] as? Data {
                self.nowPlaying.albumArt = NSImage(data: artData)
            } else {
                self.nowPlaying.albumArt = nil
            }

            // Playback rate as secondary signal for state
            if let rate = info[MRInfoKey.playbackRate] as? Double {
                if rate > 0 {
                    self.nowPlaying.playbackState = .playing
                }
            }
        }
    }

    private func refreshPlaybackState() {
        loader.getIsPlaying?(DispatchQueue.main) { [weak self] isPlaying in
            guard let self else { return }
            self.nowPlaying.playbackState = isPlaying ? .playing : .paused
        }
    }

    private func refreshNowPlayingApp() {
        loader.getNowPlayingClient?(DispatchQueue.main) { [weak self] client in
            guard let self else { return }
            // The client object has a bundleIdentifier property accessible via KVC
            if let client = client,
               let bundleID = (client as? NSObject)?.value(forKey: "bundleIdentifier") as? String {
                self.nowPlaying.appBundleID = bundleID
                self.updateSourceAppIcon(bundleID: bundleID)
            }
        }
    }

    /// Update cached source app icon only when the bundle ID changes.
    private func updateSourceAppIcon(bundleID: String) {
        guard bundleID != lastIconBundleID else { return }
        lastIconBundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            sourceAppIcon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            sourceAppIcon = nil
        }
    }
}
