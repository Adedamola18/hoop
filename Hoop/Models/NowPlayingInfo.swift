import AppKit

enum PlaybackState {
    case playing
    case paused
    case stopped
    case unknown
}

/// What the active media source lets us do. Sources that expose no
/// control interface (e.g. a browser tab) report an empty set.
struct MediaCapabilities: OptionSet {
    let rawValue: UInt8

    static let metadata     = MediaCapabilities(rawValue: 1 << 0)
    static let playPause    = MediaCapabilities(rawValue: 1 << 1)
    static let nextPrevious = MediaCapabilities(rawValue: 1 << 2)
    static let artwork      = MediaCapabilities(rawValue: 1 << 3)

    static let all: MediaCapabilities = [.metadata, .playPause, .nextPrevious, .artwork]
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
    var capabilities: MediaCapabilities = .all

    var isControllable: Bool { capabilities.contains(.playPause) }
    var hasTrack: Bool { title != nil }
}
