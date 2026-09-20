// Hoop/Services/MediaService.swift
import AppKit
import os.log

private let mediaLog = Logger(subsystem: "com.hoops.hoop", category: "MediaService")

// MARK: - Protocol

protocol MediaServiceProtocol {
    var nowPlaying: NowPlayingInfo { get }
    var isAvailable: Bool { get }

    func playPause()
    func nextTrack()
    func previousTrack()
    func startObserving()
    func stopObserving()
}

// MARK: - MediaService (coordinator)

/// Coordinates media sources: generic audio detection (`AudioProcessMonitor`),
/// per-app adapters (`ScriptablePlayerAdapter` rows + `MediaRemoteAdapter` catch-all),
/// and the pure `MediaArbiter` that decides who is shown and who gets paused.
@Observable
final class MediaService: MediaServiceProtocol {

    // Public surface (unchanged)
    private(set) var nowPlaying = NowPlayingInfo(playbackState: .unknown)
    private(set) var sourceAppIcon: NSImage?
    private(set) var activeBundleID: String?
    var isAvailable: Bool { !scriptable.isEmpty || mediaRemote.isLoaded }

    // Layers
    @ObservationIgnored private let monitor = AudioProcessMonitor()
    @ObservationIgnored private let mediaRemote = MediaRemoteAdapter()
    @ObservationIgnored private var scriptable: [String: ScriptablePlayerAdapter] = [:]
    @ObservationIgnored private var arbiter = MediaArbiter()

    // State keyed by bundle ID
    @ObservationIgnored private var latestInfo: [String: NowPlayingInfo] = [:]
    @ObservationIgnored private var lastStartedAt: [String: Date] = [:]
    @ObservationIgnored private var outputting: Set<String> = []
    @ObservationIgnored private var previouslyPlaying: Set<String> = []
    @ObservationIgnored private var lastIconBundleID: String?
    @ObservationIgnored private var isObserving = false
    @ObservationIgnored private var mediaRemoteOwnedID: String?

    init() {
        for row in MediaSourceCatalog.players {
            scriptable[row.bundleID] = ScriptablePlayerAdapter(descriptor: row)
        }
    }

    // Adapter commands and capability reads are main-queue-only; every entry point below runs on main.
    // MARK: Commands → active adapter

    func playPause()     { activeAdapter?.playPause() }
    func nextTrack()     { activeAdapter?.nextTrack() }
    func previousTrack() { activeAdapter?.previousTrack() }

    private var activeAdapter: MediaSourceAdapter? {
        guard let id = activeBundleID else { return nil }
        return adapter(for: id)
    }

    private func adapter(for bundleID: String) -> MediaSourceAdapter? {
        if let s = scriptable[bundleID] { return s }
        if mediaRemote.bundleID == bundleID { return mediaRemote }
        return nil
    }

    // MARK: Observation

    func startObserving() {
        guard !isObserving else { return }
        isObserving = true

        for (id, adapter) in scriptable {
            adapter.onUpdate = { [weak self] info in self?.handleUpdate(bundleID: id, info: info) }
            adapter.startObserving()
        }
        mediaRemote.onUpdate = { [weak self] info in
            guard let self else { return }
            let newID = info.appBundleID
            if self.mediaRemoteOwnedID != newID {
                if let old = self.mediaRemoteOwnedID, self.scriptable[old] == nil {
                    self.latestInfo[old] = nil
                    self.lastStartedAt[old] = nil
                    self.previouslyPlaying.remove(old)
                }
                self.mediaRemoteOwnedID = newID
                if newID == nil {
                    self.reconcile(now: Date())
                    return
                }
            }
            guard let id = newID, self.scriptable[id] == nil else { return }
            self.handleUpdate(bundleID: id, info: info)
        }
        mediaRemote.startObserving()

        monitor.onSnapshot = { [weak self] snap in self?.handleSnapshot(snap) }
        monitor.start()

        mediaLog.info("MediaService: observing \(self.scriptable.count) scriptable players, MediaRemote loaded=\(self.mediaRemote.isLoaded), CoreAudio monitor=\(AudioProcessMonitor.isSupported)")
    }

    func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        scriptable.values.forEach {
            $0.stopObserving()
            $0.onUpdate = nil
        }
        mediaRemote.stopObserving()
        mediaRemote.onUpdate = nil
        monitor.stop()
        monitor.onSnapshot = nil
    }

    // MARK: Inputs

    private func handleUpdate(bundleID: String, info: NowPlayingInfo) {
        latestInfo[bundleID] = info
        reconcile(now: Date())
    }

    private func handleSnapshot(_ snap: AudioProcessMonitor.Snapshot) {
        outputting = snap.outputting
        reconcile(now: snap.timestamp)
    }

    // MARK: Reconcile

    private func reconcile(now: Date) {
        let staleIDs = latestInfo.compactMap { id, info -> String? in
            (info.playbackState == .stopped && !info.hasTrack && !outputting.contains(id)) ? id : nil
        }
        for id in staleIDs {
            latestInfo[id] = nil
            lastStartedAt[id] = nil
            previouslyPlaying.remove(id)
        }

        let known = Set(latestInfo.keys).union(outputting)
        var states: [MediaArbiter.SourceState] = []
        var nowPlayingSet: Set<String> = []

        for id in known {
            let info = latestInfo[id]
            let isOut = outputting.contains(id)
            let state = info?.playbackState ?? (isOut ? .playing : .unknown)
            let playing = isOut || state == .playing
            if playing {
                nowPlayingSet.insert(id)
                if !previouslyPlaying.contains(id) { lastStartedAt[id] = now }
            }
            let controllable = (info?.capabilities ?? adapter(for: id)?.capabilities ?? []).contains(.playPause)
            states.append(.init(
                bundleID: id,
                isOutputtingAudio: isOut,
                playbackState: state,
                isControllable: controllable,
                hasTrack: info?.hasTrack ?? isOut,
                lastStartedAt: lastStartedAt[id]))
        }
        previouslyPlaying = nowPlayingSet

        let decision = arbiter.decide(sources: states, now: now)

        for id in decision.pauseBundleIDs {
            mediaLog.info("Arbiter: pausing \(id) in favour of \(decision.activeBundleID ?? "nil")")
            adapter(for: id)?.pause()
        }

        activeBundleID = decision.activeBundleID
        nowPlaying = displayInfo(for: decision.activeBundleID)
        updateIcon(for: decision.activeBundleID)
    }

    /// Adapter-provided info when we have it; otherwise an honest minimal card
    /// for an app we can hear but cannot talk to.
    private func displayInfo(for bundleID: String?) -> NowPlayingInfo {
        guard let id = bundleID else { return NowPlayingInfo(playbackState: .unknown) }
        if let info = latestInfo[id],
           !(!info.hasTrack && info.playbackState != .playing && outputting.contains(id)) {
            return info
        }
        var synth = NowPlayingInfo(playbackState: outputting.contains(id) ? .playing : .unknown)
        synth.appBundleID = id
        synth.title = NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName ?? id
        synth.artist = "Playing"
        synth.capabilities = []
        return synth
    }

    private func updateIcon(for bundleID: String?) {
        guard bundleID != lastIconBundleID else { return }
        lastIconBundleID = bundleID
        guard let id = bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            sourceAppIcon = nil
            return
        }
        sourceAppIcon = NSWorkspace.shared.icon(forFile: url.path)
    }
}
