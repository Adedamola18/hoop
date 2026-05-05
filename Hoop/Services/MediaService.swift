import AppKit
import Observation
import os.log

private let mediaLog = Logger(subsystem: "com.hoops.hoop", category: "MediaService")

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
    var albumName: String?
    var albumArt: NSImage?
    var playbackState: PlaybackState
    var appBundleID: String?
    var duration: TimeInterval?
    var elapsedTime: TimeInterval?

    var isAppleMusic: Bool { appBundleID == "com.apple.Music" }
    var isSpotify: Bool { appBundleID == "com.spotify.client" }
    var isRichMediaApp: Bool { isAppleMusic || isSpotify }
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
    static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
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

    var isLoaded: Bool { handle != nil }

    private init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        handle = dlopen(path, RTLD_LAZY)

        guard handle != nil else {
            mediaLog.error("Failed to load MediaRemote.framework")
            getNowPlayingInfo = nil
            getIsPlaying = nil
            sendCommand = nil
            registerForNotifications = nil
            unregisterForNotifications = nil
            return
        }

        getNowPlayingInfo = Self.loadFunc(handle!, "MRMediaRemoteGetNowPlayingInfo")
        getIsPlaying = Self.loadFunc(handle!, "MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        sendCommand = Self.loadFunc(handle!, "MRMediaRemoteSendCommand")
        registerForNotifications = Self.loadFunc(handle!, "MRMediaRemoteRegisterForNowPlayingNotifications")
        unregisterForNotifications = Self.loadFunc(handle!, "MRMediaRemoteUnregisterForNowPlayingNotifications")
    }

    private static func loadFunc<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    deinit {
        if let handle { dlclose(handle) }
    }
}

// MARK: - MediaService

@Observable
final class MediaService: MediaServiceProtocol {

    var nowPlaying = NowPlayingInfo(playbackState: .unknown)
    var sourceAppIcon: NSImage?
    var isAvailable: Bool { MediaRemoteLoader.shared.isLoaded }

    private var isObserving = false
    private let loader = MediaRemoteLoader.shared
    private var lastIconBundleID: String?
    /// Whether MediaRemote returned real data (if false, we rely on app-specific fallback).
    private var mediaRemoteWorks = false
    /// Polling timer for Apple Music (no distributed notification support).
    private var appleMusicPollTimer: DispatchSourceTimer?
    /// Artwork cache for Spotify (fetched separately from album art URL).
    private var lastSpotifyTrackID: String?

    // MARK: - Commands

    func playPause() {
        _ = loader.sendCommand?(MRCommand.togglePlayPause.rawValue, nil)
    }

    func nextTrack() {
        _ = loader.sendCommand?(MRCommand.nextTrack.rawValue, nil)
    }

    func previousTrack() {
        _ = loader.sendCommand?(MRCommand.previousTrack.rawValue, nil)
    }

    // MARK: - Observation

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        // Try MediaRemote first
        if loader.isLoaded {
            loader.registerForNotifications?(DispatchQueue.main)

            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(handleMediaRemoteChange),
                           name: Notification.Name(MRNotification.nowPlayingInfoDidChange), object: nil)
            nc.addObserver(self, selector: #selector(handleMediaRemoteChange),
                           name: Notification.Name(MRNotification.nowPlayingApplicationIsPlayingDidChange), object: nil)
            nc.addObserver(self, selector: #selector(handleMediaRemoteChange),
                           name: Notification.Name(MRNotification.nowPlayingApplicationDidChange), object: nil)

            // Probe MediaRemote — if it returns data, use it exclusively
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.probeMediaRemote()
            }
        }

        // Always register for Spotify distributed notifications (reliable on macOS 15+)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSpotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        // Start Apple Music polling (every 3s, lightweight AppleScript check)
        startAppleMusicPolling()

        mediaLog.info("MediaService: started observing (MediaRemote + app-specific fallbacks)")
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false

        loader.unregisterForNotifications?()
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        stopAppleMusicPolling()
    }

    // MARK: - MediaRemote Probe

    /// Check if MediaRemote actually returns data. On macOS 15+, it may return empty dicts.
    private func probeMediaRemote() {
        loader.getNowPlayingInfo?(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            if info.count > 0 {
                mediaLog.info("MediaRemote probe: \(info.count) keys — using MediaRemote as primary source")
                self.mediaRemoteWorks = true
                self.applyMediaRemoteInfo(info)
            } else {
                mediaLog.info("MediaRemote probe: 0 keys — falling back to app-specific sources")
                self.mediaRemoteWorks = false
                // Do an immediate poll for current state
                self.pollAppleMusic()
            }
        }
    }

    // MARK: - MediaRemote Handlers

    @objc private func handleMediaRemoteChange() {
        guard mediaRemoteWorks else { return }
        loader.getNowPlayingInfo?(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            self.applyMediaRemoteInfo(info)
        }
        loader.getIsPlaying?(DispatchQueue.main) { [weak self] isPlaying in
            guard let self else { return }
            self.nowPlaying.playbackState = isPlaying ? .playing : .paused
        }
    }

    private func applyMediaRemoteInfo(_ info: [String: Any]) {
        nowPlaying.title = info[MRInfoKey.title] as? String
        nowPlaying.artist = info[MRInfoKey.artist] as? String
        nowPlaying.albumName = info[MRInfoKey.album] as? String
        nowPlaying.duration = info[MRInfoKey.duration] as? TimeInterval
        nowPlaying.elapsedTime = info[MRInfoKey.elapsedTime] as? TimeInterval

        if let artData = info[MRInfoKey.artworkData] as? Data {
            nowPlaying.albumArt = NSImage(data: artData)
        } else {
            nowPlaying.albumArt = nil
        }

        if let rate = info[MRInfoKey.playbackRate] as? Double, rate > 0 {
            nowPlaying.playbackState = .playing
        }
    }

    // MARK: - Spotify (Distributed Notifications)

    @objc private func handleSpotifyNotification(_ notif: Notification) {
        guard !mediaRemoteWorks else { return }
        guard let info = notif.userInfo else { return }

        let state = info["Player State"] as? String ?? ""
        let title = info["Name"] as? String
        let artist = info["Artist"] as? String
        let album = info["Album"] as? String
        let durationMs = info["Duration"] as? Int
        let position = info["Playback Position"] as? Double
        let trackID = info["Track ID"] as? String

        mediaLog.info("Spotify notification — state: \(state), title: \(title ?? "nil"), artist: \(artist ?? "nil")")

        nowPlaying.title = title
        nowPlaying.artist = artist
        nowPlaying.albumName = album
        nowPlaying.appBundleID = "com.spotify.client"

        if let durationMs {
            nowPlaying.duration = Double(durationMs) / 1000.0
        }
        nowPlaying.elapsedTime = position

        switch state {
        case "Playing":
            nowPlaying.playbackState = .playing
        case "Paused":
            nowPlaying.playbackState = .paused
        case "Stopped":
            nowPlaying.playbackState = .stopped
            nowPlaying.title = nil
            nowPlaying.artist = nil
            nowPlaying.albumArt = nil
        default:
            break
        }

        updateSourceAppIcon(bundleID: "com.spotify.client")

        // Fetch artwork if track changed
        if let trackID, trackID != lastSpotifyTrackID {
            lastSpotifyTrackID = trackID
            fetchSpotifyArtwork()
        }
    }

    /// Fetch album artwork from Spotify via osascript + URL download.
    private func fetchSpotifyArtwork() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let urlString = Self.runAppleScript("""
                tell application "Spotify"
                    if player state is not stopped then
                        return artwork url of current track
                    end if
                end tell
                """),
                  let url = URL(string: urlString) else { return }

            // Download the artwork image
            if let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self?.nowPlaying.albumArt = image
                }
            }
        }
    }

    // MARK: - Apple Music (AppleScript Polling)

    private func startAppleMusicPolling() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 1, repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.pollAppleMusic()
        }
        timer.resume()
        appleMusicPollTimer = timer
    }

    private func stopAppleMusicPolling() {
        appleMusicPollTimer?.cancel()
        appleMusicPollTimer = nil
    }

    private func pollAppleMusic() {
        guard !mediaRemoteWorks else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Check if Music app is running first (cheap check)
            let running = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "com.apple.Music"
            }
            guard running else {
                DispatchQueue.main.async {
                    guard let self, self.nowPlaying.appBundleID == "com.apple.Music" else { return }
                    self.nowPlaying.playbackState = .stopped
                }
                return
            }

            let script = """
            tell application "Music"
                set pState to player state as text
                if pState is "playing" or pState is "paused" then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDuration to duration of current track
                    set pPos to player position
                    return pState & "|" & tName & "|" & tArtist & "|" & tAlbum & "|" & tDuration & "|" & pPos
                else
                    return "stopped"
                end if
            end tell
            """

            guard let output = Self.runAppleScript(script) else {
                mediaLog.debug("Apple Music poll: no output or error")
                return
            }

            if output == "stopped" {
                DispatchQueue.main.async {
                    guard let self else { return }
                    if self.nowPlaying.appBundleID == "com.apple.Music" {
                        self.nowPlaying.playbackState = .stopped
                    }
                }
                return
            }

            let parts = output.components(separatedBy: "|")
            guard parts.count >= 6 else { return }

            let pState = parts[0]
            let title = parts[1]
            let artist = parts[2]
            let album = parts[3]
            let duration = Double(parts[4]) ?? 0
            let position = Double(parts[5]) ?? 0

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Only update if no Spotify data is newer
                let spotifyPlaying = self.nowPlaying.appBundleID == "com.spotify.client" &&
                    (self.nowPlaying.playbackState == .playing || self.nowPlaying.playbackState == .paused)

                // Music takes priority if it's playing, or if Spotify isn't active
                if pState == "playing" || !spotifyPlaying {
                    self.nowPlaying.title = title
                    self.nowPlaying.artist = artist
                    self.nowPlaying.albumName = album
                    self.nowPlaying.duration = duration
                    self.nowPlaying.elapsedTime = position
                    self.nowPlaying.appBundleID = "com.apple.Music"
                    self.nowPlaying.playbackState = pState == "playing" ? .playing : .paused
                    self.updateSourceAppIcon(bundleID: "com.apple.Music")
                }
            }

            // Fetch artwork separately on track change
            self?.fetchAppleMusicArtwork()
        }
    }

    private var lastAppleMusicArtworkTitle: String?

    private func fetchAppleMusicArtwork() {
        let currentTitle = nowPlaying.title
        guard currentTitle != lastAppleMusicArtworkTitle,
              nowPlaying.appBundleID == "com.apple.Music" else { return }
        lastAppleMusicArtworkTitle = currentTitle

        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Use osascript to export artwork to a temp file, then load it
            let tmpPath = NSTemporaryDirectory() + "hoop_musicart.jpg"
            let script = """
            tell application "Music"
                try
                    set artData to raw data of artwork 1 of current track
                    set filePath to POSIX file "\(tmpPath)"
                    set fileRef to open for access filePath with write permission
                    set eof of fileRef to 0
                    write artData to fileRef
                    close access fileRef
                    return "ok"
                on error
                    return "noart"
                end try
            end tell
            """
            guard let result = Self.runAppleScript(script), result == "ok" else { return }

            if let image = NSImage(contentsOfFile: tmpPath) {
                DispatchQueue.main.async {
                    self?.nowPlaying.albumArt = image
                }
            }
            try? FileManager.default.removeItem(atPath: tmpPath)
        }
    }

    // MARK: - AppleScript Helper

    /// Run an AppleScript via osascript process and return trimmed stdout, or nil on failure.
    private static func runAppleScript(_ script: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Source App Icon

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
