import Foundation
import Observation

extension Notification.Name {
    static let activationTriggerDidChange = Notification.Name("activationTriggerDidChange")
}

enum ActivationTrigger: Int, CaseIterable {
    case hover = 0
    case click = 1
    case hotkey = 2

    var label: String {
        switch self {
        case .hover: "Hover"
        case .click: "Click"
        case .hotkey: "Keyboard Shortcut"
        }
    }

    static var current: ActivationTrigger {
        let raw = UserDefaults.standard.integer(forKey: "activationTrigger")
        return ActivationTrigger(rawValue: raw) ?? .hover
    }
}

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

    /// Size of the collapsed notch/pill area in points. Set by NotchWindowManager.
    var collapsedSize: CGSize = .zero

    /// Configurable expanded width (400-800pt, default 600pt).
    var expandedWidth: CGFloat {
        let w = UserDefaults.standard.double(forKey: "expandedWidth")
        return w > 0 ? max(400, min(800, w)) : 600
    }

    /// Height of the expanded overlay.
    static let expandedHeight: CGFloat = 200
}
