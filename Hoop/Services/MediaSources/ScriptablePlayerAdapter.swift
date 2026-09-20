// Hoop/Services/MediaSources/ScriptablePlayerAdapter.swift
import AppKit
import os.log

private let log = Logger(subsystem: "com.hoops.hoop", category: "ScriptablePlayerAdapter")

/// Drives any player that speaks the iTunes-style AppleScript dictionary
/// (`player state`, `current track`, `playpause`, `next track`, `previous track`).
/// One instance per `ScriptablePlayerDescriptor` row.
///
/// Queue discipline: `queue` runs all AppleScript and produces plain values
/// (`PollOutcome`, `Bool` success flags). `info`, `capabilities`,
/// `lastArtworkKey`, `consecutivePollFailures`, and `isDegraded` are
/// MAIN-QUEUE-ONLY state — they are only ever read or written from methods
/// that are documented as running on main (`apply`, `publish`,
/// `applyArtwork`, `degrade`, `recover`, `handleEvent`, and the main hop
/// inside `send`).
final class ScriptablePlayerAdapter: MediaSourceAdapter {

    /// Outcome of a single background poll, carrying only plain data so the
    /// background queue never touches main-only state.
    private enum PollOutcome {
        case notRunning
        case stopped
        case playing(NowPlayingInfo)
        case failed
    }

    private enum DegradeReason {
        case commandFailure
        case metadataFailure
    }

    let descriptor: ScriptablePlayerDescriptor
    var bundleID: String { descriptor.bundleID }
    var displayName: String { descriptor.appName }
    private(set) var capabilities: MediaCapabilities = .all
    var onUpdate: ((NowPlayingInfo) -> Void)?

    /// The capability set this player is entitled to when scripting is healthy.
    private let baseCapabilities: MediaCapabilities

    private let queue = DispatchQueue(label: "com.hoops.hoop.scriptable", qos: .utility)
    /// Artwork fetches (AppleScript raw-data export, or an HTTP download of an
    /// artwork URL) run here instead of on `queue`, so a stalled fetch can never
    /// delay an arbiter-issued `pause()`/`play()` command dispatched on `queue`.
    private let artworkQueue = DispatchQueue(label: "com.hoops.hoop.scriptable.artwork", qos: .utility)
    private var pollTimer: DispatchSourceTimer?
    private var isObserving = false

    // MARK: Main-queue-only state
    private var info: NowPlayingInfo
    private var lastArtworkKey: String?
    private var consecutivePollFailures = 0
    private var isDegraded = false

    init(descriptor: ScriptablePlayerDescriptor) {
        self.descriptor = descriptor
        let base: MediaCapabilities = descriptor.artworkStrategy == .none ? [.metadata, .playPause, .nextPrevious] : .all
        self.baseCapabilities = base
        var initial = NowPlayingInfo(playbackState: .unknown)
        initial.appBundleID = descriptor.bundleID
        initial.capabilities = base
        self.info = initial
        self.capabilities = base
    }

    deinit {
        stopObserving()
    }

    // MARK: Observation

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        if let name = descriptor.eventNotificationName {
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(handleSpotifyDialectEvent(_:)),
                name: NSNotification.Name(name), object: nil)
        }

        // Poll as the primary source, or as a slow safety net when events exist.
        let interval = descriptor.eventNotificationName == nil ? descriptor.pollInterval : max(descriptor.pollInterval, 10)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: interval)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        pollTimer = timer
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        pollTimer?.cancel()
        pollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: Commands

    func play()          { send("play") }
    func pause()         { send("pause") }
    func playPause()     { send("playpause") }
    func nextTrack()     { send("next track") }
    func previousTrack() { send("previous track") }

    private func send(_ command: String) {
        guard capabilities.contains(.playPause) else { return }
        queue.async { [weak self] in
            guard let self else { return }
            let ok = AppleScriptRunner.run("tell application \"\(self.descriptor.appName)\" to \(command)") != nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if ok {
                    self.recover()
                } else {
                    self.degrade(reason: .commandFailure)
                }
            }
            // Re-poll shortly so the UI reflects the new state without waiting a full interval.
            self.queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.poll() }
        }
    }

    // MARK: Fast path (distributed notification, Spotify dialect)

    /// Handles the distributed notification a descriptor opts into via
    /// `eventNotificationName`. The payload format is Spotify's own
    /// `PlaybackStateChanged` dialect (keys: `Player State`, `Name`, `Artist`,
    /// `Album`, `Duration` in ms, `Playback Position` in seconds, `Track ID`).
    /// Any descriptor that sets `eventNotificationName` is assumed to emit this
    /// same dialect; there is no per-player key mapping.
    @objc private func handleSpotifyDialectEvent(_ notif: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleSpotifyDialectEvent(notif) }
            return
        }
        guard let user = notif.userInfo else { return }
        let state = user["Player State"] as? String ?? ""
        var next = info
        next.title = user["Name"] as? String
        next.artist = user["Artist"] as? String
        next.albumName = user["Album"] as? String
        if let ms = user["Duration"] as? Int { next.duration = Double(ms) / 1000 }
        next.elapsedTime = user["Playback Position"] as? Double
        switch state {
        case "Playing": next.playbackState = .playing
        case "Paused":  next.playbackState = .paused
        case "Stopped":
            next = stoppedInfo()
        default: break
        }
        let artKey = (user["Track ID"] as? String) ?? next.title
        publish(next, artworkKey: artKey)
    }

    // MARK: Polling

    private var isAppRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == descriptor.bundleID }
    }

    /// Runs entirely on `queue`. Builds plain data only — never reads or
    /// writes main-only state — then hops to main via `apply`.
    private func poll() {
        guard isAppRunning else {
            DispatchQueue.main.async { [weak self] in self?.apply(.notRunning) }
            return
        }

        let script = """
        tell application "\(descriptor.appName)"
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
        guard let out = AppleScriptRunner.run(script) else {
            DispatchQueue.main.async { [weak self] in self?.apply(.failed) }
            return
        }

        if out == "stopped" {
            DispatchQueue.main.async { [weak self] in self?.apply(.stopped) }
            return
        }

        let parts = out.components(separatedBy: "|")
        guard parts.count >= 6 else {
            DispatchQueue.main.async { [weak self] in self?.apply(.failed) }
            return
        }

        let rawDuration = Double(parts[4]) ?? 0
        var fresh = NowPlayingInfo(playbackState: parts[0] == "playing" ? .playing : .paused)
        fresh.title = parts[1]
        fresh.artist = parts[2]
        fresh.albumName = parts[3]
        fresh.duration = descriptor.durationUnit == .milliseconds ? rawDuration / 1000 : rawDuration
        fresh.elapsedTime = Double(parts[5]) ?? 0
        fresh.appBundleID = descriptor.bundleID
        DispatchQueue.main.async { [weak self] in self?.apply(.playing(fresh)) }
    }

    /// Main-only. Applies a background poll's outcome: updates failure
    /// counters, recovers/degrades capabilities, and publishes.
    private func apply(_ outcome: PollOutcome) {
        switch outcome {
        case .notRunning:
            if info.playbackState != .stopped && info.playbackState != .unknown {
                publish(stoppedInfo(), artworkKey: nil)
            }
        case .stopped:
            consecutivePollFailures = 0
            recover()
            if info.playbackState != .stopped {
                publish(stoppedInfo(), artworkKey: nil)
            }
        case .playing(let fresh):
            consecutivePollFailures = 0
            recover()
            let artKey = "\(fresh.title ?? "")|\(fresh.artist ?? "")|\(fresh.albumName ?? "")"
            publish(fresh, artworkKey: artKey)
        case .failed:
            consecutivePollFailures += 1
            if consecutivePollFailures >= 3 {
                degrade(reason: .metadataFailure)
            }
        }
    }

    // MARK: Capability degradation (main-only)

    /// Marks the source uncontrollable (or, for metadata failures, fully
    /// unusable) the first time scripting starts failing. Idempotent within
    /// a failure episode — only the first call logs and publishes.
    private func degrade(reason: DegradeReason) {
        guard !isDegraded else { return }
        isDegraded = true
        switch reason {
        case .commandFailure:
            capabilities = [.metadata]
            log.error("\(self.descriptor.appName): control script failed; marking uncontrollable")
        case .metadataFailure:
            capabilities = []
            log.error("\(self.descriptor.appName): metadata script failing; marking uncontrollable")
        }
        switch reason {
        case .commandFailure:
            // Metadata is still trustworthy here — only control failed. Keep the
            // current card, just narrow its capabilities.
            info.capabilities = capabilities
        case .metadataFailure:
            // Metadata itself can no longer be trusted. Reset to a stopped card
            // (capabilities == []) so the coordinator's stale-source prune can
            // drop it unless the app is genuinely outputting audio.
            info = stoppedInfo()
            info.capabilities = capabilities
        }
        onUpdate?(info)
    }

    /// Restores `baseCapabilities` the first time scripting succeeds again
    /// after a degradation episode.
    private func recover() {
        guard isDegraded else { return }
        isDegraded = false
        capabilities = baseCapabilities
        info.capabilities = capabilities
        onUpdate?(info)
        log.info("\(self.descriptor.appName): scripting recovered")
    }

    // MARK: Publish + artwork

    /// Main-only. Builds a "stopped" reset from the current `info`,
    /// clearing track data while keeping identity and capabilities.
    private func stoppedInfo() -> NowPlayingInfo {
        var stopped = info
        stopped.playbackState = .stopped
        stopped.title = nil
        stopped.artist = nil
        stopped.albumName = nil
        stopped.albumArt = nil
        stopped.duration = nil
        stopped.elapsedTime = nil
        return stopped
    }

    /// Called from main only. Stores, notifies on main, and fetches artwork
    /// if the track changed.
    private func publish(_ next: NowPlayingInfo, artworkKey: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let keepArt = (artworkKey != nil && artworkKey == self.lastArtworkKey) ? self.info.albumArt : nil
            var stored = next
            stored.albumArt = keepArt ?? next.albumArt
            stored.appBundleID = self.descriptor.bundleID
            stored.capabilities = self.capabilities
            self.info = stored
            self.onUpdate?(stored)

            if let key = artworkKey, key != self.lastArtworkKey, stored.playbackState != .stopped {
                self.lastArtworkKey = key
                self.fetchArtwork(forKey: key)
            }
        }
    }

    private func fetchArtwork(forKey key: String) {
        switch descriptor.artworkStrategy {
        case .none:
            return
        case .url:
            // Runs on artworkQueue, not queue: an AppleScript call plus a
            // synchronous HTTP download here must never delay a pause()/play()
            // dispatched on queue.
            artworkQueue.async { [weak self] in
                guard let self,
                      let urlString = AppleScriptRunner.run("""
                        tell application "\(self.descriptor.appName)"
                            if player state is not stopped then
                                return artwork url of current track
                            end if
                        end tell
                        """),
                      let url = URL(string: urlString),
                      let data = Self.downloadWithTimeout(url),
                      let image = NSImage(data: data) else { return }
                self.applyArtwork(image, forKey: key)
            }
        case .rawData:
            // Still runs AppleScript, but on artworkQueue so it cannot block commands.
            artworkQueue.async { [weak self] in
                guard let self else { return }
                let tmp = NSTemporaryDirectory() + "hoop_art_\(self.descriptor.bundleID).jpg"
                let script = """
                tell application "\(self.descriptor.appName)"
                    try
                        set artData to raw data of artwork 1 of current track
                        set filePath to POSIX file "\(tmp)"
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
                guard AppleScriptRunner.run(script) == "ok",
                      let image = NSImage(contentsOfFile: tmp) else { return }
                try? FileManager.default.removeItem(atPath: tmp)
                self.applyArtwork(image, forKey: key)
            }
        }
    }

    /// Synchronous, timeout-bounded download. Safe to call from a background
    /// queue only (blocks the calling thread on a semaphore).
    private static func downloadWithTimeout(_ url: URL) -> Data? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?
        let task = session.dataTask(with: url) { data, _, _ in
            result = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 11)
        return result
    }

    private func applyArtwork(_ image: NSImage, forKey key: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.lastArtworkKey == key else { return }   // track changed meanwhile
            self.info.albumArt = image
            self.onUpdate?(self.info)
        }
    }
}
