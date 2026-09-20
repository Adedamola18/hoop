import Foundation

enum ArtworkStrategy {
    /// `raw data of artwork 1 of current track` (Apple Music dialect).
    case rawData
    /// `artwork url of current track` then HTTP download (Spotify dialect).
    case url
    case none
}

enum DurationUnit {
    case seconds
    case milliseconds
}

/// Everything needed to drive an iTunes-dialect scriptable player.
/// Adding a player is adding a row to `MediaSourceCatalog.players`.
struct ScriptablePlayerDescriptor {
    let bundleID: String
    /// Name used in `tell application "<appName>"`.
    let appName: String
    /// Optional distributed notification carrying playback state. The payload
    /// MUST use Spotify's `PlaybackStateChanged` dialect (keys: `Player State`,
    /// `Name`, `Artist`, `Album`, `Duration` [ms], `Playback Position` [s],
    /// `Track ID`). Leave nil for players without such a notification; polling
    /// covers them. When set, polling drops to a slow safety-net cadence.
    let eventNotificationName: String?
    let artworkStrategy: ArtworkStrategy
    /// Unit of `duration of current track` in this app's dictionary.
    let durationUnit: DurationUnit
    let pollInterval: TimeInterval

    init(bundleID: String,
         appName: String,
         eventNotificationName: String? = nil,
         artworkStrategy: ArtworkStrategy,
         durationUnit: DurationUnit,
         pollInterval: TimeInterval = 3.0) {
        self.bundleID = bundleID
        self.appName = appName
        self.eventNotificationName = eventNotificationName
        self.artworkStrategy = artworkStrategy
        self.durationUnit = durationUnit
        self.pollInterval = pollInterval
    }
}

enum MediaSourceCatalog {
    static let players: [ScriptablePlayerDescriptor] = [
        ScriptablePlayerDescriptor(
            bundleID: "com.apple.Music",
            appName: "Music",
            artworkStrategy: .rawData,
            durationUnit: .seconds
        ),
        ScriptablePlayerDescriptor(
            bundleID: "com.spotify.client",
            appName: "Spotify",
            eventNotificationName: "com.spotify.client.PlaybackStateChanged",
            artworkStrategy: .url,
            durationUnit: .milliseconds
        ),
    ]
}
