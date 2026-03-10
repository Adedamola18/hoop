import Foundation
import Observation

@Observable
final class NotchState {

    enum Phase {
        case idle
        case expanding
        case expanded
        case tray
        case hud
    }

    var phase: Phase = .idle
    var screenHasNotch: Bool = true
}
