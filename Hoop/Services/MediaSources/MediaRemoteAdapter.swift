// Hoop/Services/MediaSources/MediaRemoteAdapter.swift
import AppKit
import os.log

private let log = Logger(subsystem: "com.hoops.hoop", category: "MediaRemoteAdapter")

// MARK: - Private framework surface

private typealias MRGetNowPlayingInfoFunc = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
private typealias MRGetIsPlayingFunc = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
private typealias MRGetNowPlayingPIDFunc = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
private typealias MRSendCommandFunc = @convention(c) (UInt32, UnsafeMutableRawPointer?) -> Bool
private typealias MRRegisterFunc = @convention(c) (DispatchQueue) -> Void
private typealias MRUnregisterFunc = @convention(c) () -> Void

private enum MRCommand: UInt32 {
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

private enum MRInfoKey {
    static let title = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
    static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
}

private enum MRNotification {
    static let infoDidChange = "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    static let isPlayingDidChange = "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
    static let appDidChange = "kMRMediaRemoteNowPlayingApplicationDidChangeNotification"
}

private final class MediaRemoteLoader {
    static let shared = MediaRemoteLoader()

    let handle: UnsafeMutableRawPointer?
    let getNowPlayingInfo: MRGetNowPlayingInfoFunc?
    let getIsPlaying: MRGetIsPlayingFunc?
    let getNowPlayingPID: MRGetNowPlayingPIDFunc?
    let sendCommand: MRSendCommandFunc?
    let register: MRRegisterFunc?
    let unregister: MRUnregisterFunc?

    var isLoaded: Bool { handle != nil }

    private init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        handle = dlopen(path, RTLD_NOW)
        guard let h = handle else {
            getNowPlayingInfo = nil; getIsPlaying = nil; getNowPlayingPID = nil
            sendCommand = nil; register = nil; unregister = nil
            return
        }
        getNowPlayingInfo = Self.load(h, "MRMediaRemoteGetNowPlayingInfo")
        getIsPlaying = Self.load(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        getNowPlayingPID = Self.load(h, "MRMediaRemoteGetNowPlayingApplicationPID")
        sendCommand = Self.load(h, "MRMediaRemoteSendCommand")
        register = Self.load(h, "MRMediaRemoteRegisterForNowPlayingNotifications")
        unregister = Self.load(h, "MRMediaRemoteUnregisterForNowPlayingNotifications")
    }

    private static func load<T>(_ h: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(h, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }
}

// MARK: - Adapter

/// Catch-all source: whatever macOS considers the "now playing" app.
/// Provides metadata when MediaRemote returns data, and control only for that one app.
final class MediaRemoteAdapter: MediaSourceAdapter {

    private let loader = MediaRemoteLoader.shared
    private var isObserving = false
    private var info = NowPlayingInfo(playbackState: .unknown)

    private(set) var nowPlayingBundleID: String?
    /// True once a probe has returned a non-empty dictionary (macOS 15+ may return empty).
    private(set) var worksOnThisSystem = false

    var isLoaded: Bool { loader.isLoaded }
    var bundleID: String { nowPlayingBundleID ?? "mediaremote.unknown" }
    var displayName: String {
        guard let id = nowPlayingBundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first,
              let name = app.localizedName else { return "Now Playing" }
        return name
    }
    var capabilities: MediaCapabilities {
        (worksOnThisSystem && nowPlayingBundleID != nil) ? .all : []
    }
    var onUpdate: ((NowPlayingInfo) -> Void)?

    // MARK: Observation

    func startObserving() {
        guard !isObserving, loader.isLoaded else { return }
        isObserving = true
        loader.register?(DispatchQueue.main)
        let nc = NotificationCenter.default
        for name in [MRNotification.infoDidChange, MRNotification.isPlayingDidChange, MRNotification.appDidChange] {
            nc.addObserver(self, selector: #selector(handleChange), name: Notification.Name(name), object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.probe() }
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        loader.unregister?()
        NotificationCenter.default.removeObserver(self)
    }

    private func probe() {
        loader.getNowPlayingInfo?(DispatchQueue.main) { [weak self] dict in
            guard let self else { return }
            self.worksOnThisSystem = !dict.isEmpty
            log.info("MediaRemote probe: \(dict.count) keys — \(self.worksOnThisSystem ? "usable" : "empty, relying on adapters")")
            if self.worksOnThisSystem { self.refresh() }
        }
    }

    @objc private func handleChange() {
        guard worksOnThisSystem else { return }
        refresh()
    }

    private func refresh() {
        loader.getNowPlayingPID?(DispatchQueue.main) { [weak self] pid in
            guard let self else { return }
            let app = pid > 0 ? NSRunningApplication(processIdentifier: pid) : nil
            self.nowPlayingBundleID = app?.bundleIdentifier
            self.loader.getNowPlayingInfo?(DispatchQueue.main) { [weak self] dict in
                guard let self else { return }
                self.apply(dict)
                self.loader.getIsPlaying?(DispatchQueue.main) { [weak self] playing in
                    guard let self else { return }
                    self.info.playbackState = playing ? .playing : .paused
                    self.emit()
                }
            }
        }
    }

    private func apply(_ dict: [String: Any]) {
        info.title = dict[MRInfoKey.title] as? String
        info.artist = dict[MRInfoKey.artist] as? String
        info.albumName = dict[MRInfoKey.album] as? String
        info.duration = dict[MRInfoKey.duration] as? TimeInterval
        info.elapsedTime = dict[MRInfoKey.elapsedTime] as? TimeInterval
        info.albumArt = (dict[MRInfoKey.artworkData] as? Data).flatMap(NSImage.init(data:))
        info.appBundleID = nowPlayingBundleID
        info.capabilities = capabilities
    }

    private func emit() {
        info.appBundleID = nowPlayingBundleID
        info.capabilities = capabilities
        onUpdate?(info)
    }

    // MARK: Commands (only reach the system now-playing app)

    func play() {
        guard capabilities.contains(.playPause) else { return }
        guard info.playbackState != .playing else { return }
        _ = loader.sendCommand?(MRCommand.togglePlayPause.rawValue, nil)
    }

    func pause() {
        guard capabilities.contains(.playPause) else { return }
        guard info.playbackState == .playing else { return }
        _ = loader.sendCommand?(MRCommand.togglePlayPause.rawValue, nil)
    }

    func playPause() {
        guard capabilities.contains(.playPause) else { return }
        _ = loader.sendCommand?(MRCommand.togglePlayPause.rawValue, nil)
    }

    func nextTrack() {
        guard capabilities.contains(.playPause) else { return }
        _ = loader.sendCommand?(MRCommand.nextTrack.rawValue, nil)
    }

    func previousTrack() {
        guard capabilities.contains(.playPause) else { return }
        _ = loader.sendCommand?(MRCommand.previousTrack.rawValue, nil)
    }
}
