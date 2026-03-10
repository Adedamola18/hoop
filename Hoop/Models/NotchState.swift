import Foundation
import Observation

extension Notification.Name {
    static let activationTriggerDidChange = Notification.Name("activationTriggerDidChange")
    static let hudSettingsDidChange = Notification.Name("hudSettingsDidChange")
    static let themeModeDidChange = Notification.Name("themeModeDidChange")
}

enum ThemeMode: Int, CaseIterable {
    case solidDark = 0
    case translucentDark = 1
    case liquidGlass = 2

    var label: String {
        switch self {
        case .solidDark: "Solid Dark"
        case .translucentDark: "Translucent Dark"
        case .liquidGlass: "Liquid Glass"
        }
    }

    var icon: String {
        switch self {
        case .solidDark: "circle.fill"
        case .translucentDark: "circle.lefthalf.filled"
        case .liquidGlass: "drop.fill"
        }
    }

    static var current: ThemeMode {
        let raw = UserDefaults.standard.integer(forKey: "themeMode")
        return ThemeMode(rawValue: raw) ?? .solidDark
    }
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
    var themeMode: ThemeMode = ThemeMode.current

    /// Size of the collapsed notch/pill area in points. Set by NotchWindowManager.
    var collapsedSize: CGSize = .zero

    /// Configurable expanded width (400-800pt, default 600pt).
    var expandedWidth: CGFloat {
        let w = UserDefaults.standard.double(forKey: "expandedWidth")
        return w > 0 ? max(400, min(800, w)) : 600
    }

    /// Configurable expanded height (150-400pt, default 200pt).
    var expandedHeight: CGFloat {
        let h = UserDefaults.standard.double(forKey: "expandedHeight")
        return h > 0 ? max(150, min(400, h)) : 200
    }

    /// Configurable content padding (8-32pt, default 16pt).
    var contentPadding: CGFloat {
        let p = UserDefaults.standard.double(forKey: "contentPadding")
        return p > 0 ? max(8, min(32, p)) : 16
    }
}
