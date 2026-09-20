import Foundation

/// One media source (an app) that Hoop can observe and, if capable, control.
/// Mirrors the MarketAdapter pattern in Services/Adapters.
protocol MediaSourceAdapter: AnyObject {
    /// Bundle identifier of the app this adapter represents.
    var bundleID: String { get }
    var displayName: String { get }
    var capabilities: MediaCapabilities { get }

    /// Called on the main queue whenever this source's now-playing info changes.
    var onUpdate: ((NowPlayingInfo) -> Void)? { get set }

    func startObserving()
    func stopObserving()

    func play()
    func pause()
    func playPause()
    func nextTrack()
    func previousTrack()
}
