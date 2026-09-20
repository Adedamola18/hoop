import Foundation

/// Decides which media source is active and which ones to pause.
/// Pure value type: no timers, no AppleScript, no observation. See spec §Layer 3.
struct MediaArbiter {

    struct SourceState {
        let bundleID: String
        let isOutputtingAudio: Bool
        let playbackState: PlaybackState
        let isControllable: Bool
        let hasTrack: Bool
        let lastStartedAt: Date?

        var isPlaying: Bool { isOutputtingAudio || playbackState == .playing }
    }

    struct Decision: Equatable {
        let activeBundleID: String?
        let pauseBundleIDs: [String]
    }

    /// How long after we pause a source we ignore it re-reporting "playing".
    static let echoWindow: TimeInterval = 2.0

    private(set) var activeBundleID: String?
    private var suppressedUntil: [String: Date] = [:]

    mutating func decide(sources: [SourceState], now: Date) -> Decision {
        suppressedUntil = suppressedUntil.filter { $0.value > now }

        let playing = sources.filter { $0.isPlaying && suppressedUntil[$0.bundleID] == nil }

        guard !playing.isEmpty else {
            return fallback(sources: sources)
        }

        // Rule 1 / 5: newest lastStartedAt wins; ties (or missing dates) keep the current active.
        let current = playing.first { $0.bundleID == activeBundleID }
        var winner: SourceState
        if let current = current {
            // A current active is in the playing set: it is only dethroned by a candidate
            // whose date is strictly greater than the current's own NON-nil date. If the
            // current has no date, it is kept regardless of any candidate's date.
            winner = current
            if current.lastStartedAt != nil {
                for candidate in playing where candidate.bundleID != winner.bundleID {
                    // Compare against the RUNNING winner's date (re-read each iteration),
                    // not the original current's date, so a middle-of-the-pack candidate
                    // can't overwrite a later, newer winner already found in this loop.
                    if let c = candidate.lastStartedAt, let w = winner.lastStartedAt, c > w {
                        winner = candidate
                    }
                }
            }
        } else {
            // No current active among the playing sources: prefer dated candidates, newest
            // wins. Seed with playing[0] — when no dates are present at all, array order is
            // the intentional tie-break.
            winner = playing[0]
            for candidate in playing where candidate.bundleID != winner.bundleID {
                if let c = candidate.lastStartedAt {
                    if let w = winner.lastStartedAt {
                        if c > w { winner = candidate }
                    } else {
                        winner = candidate
                    }
                }
            }
        }
        activeBundleID = winner.bundleID

        // Rule 2 / 3: pause every other controllable playing source, once — but only when
        // the winner itself is controllable. An uncontrollable winner (Zoom, a game, a
        // browser tab) may be shown as active, but it never pauses anything else (spec
        // §Open decisions: uncontrollable sources "never pause others").
        let toPause = winner.isControllable
            ? playing
                .filter { $0.bundleID != winner.bundleID && $0.isControllable }
                .map(\.bundleID)
            : []
        for id in toPause {
            suppressedUntil[id] = now.addingTimeInterval(Self.echoWindow)
        }
        return Decision(activeBundleID: winner.bundleID, pauseBundleIDs: toPause)
    }

    /// Rule 4: nothing is playing. Keep the active source if it still has a track,
    /// else pick any source with a track, else nil. Never pauses.
    private mutating func fallback(sources: [SourceState]) -> Decision {
        if let active = activeBundleID,
           let cur = sources.first(where: { $0.bundleID == active }),
           cur.hasTrack {
            return Decision(activeBundleID: active, pauseBundleIDs: [])
        }
        activeBundleID = sources.first { $0.hasTrack }?.bundleID
        return Decision(activeBundleID: activeBundleID, pauseBundleIDs: [])
    }
}
