import Foundation

// MARK: - Gesture Action Enums

enum HorizontalSwipeAction: Int, CaseIterable {
    case skipTrack = 0
    case switchWidget = 1
    case none = 2

    var label: String {
        switch self {
        case .skipTrack: "Skip Track"
        case .switchWidget: "Switch Widget"
        case .none: "None"
        }
    }

    static var current: HorizontalSwipeAction {
        let raw = UserDefaults.standard.integer(forKey: "gestureHorizontalSwipe")
        return HorizontalSwipeAction(rawValue: raw) ?? .skipTrack
    }
}

enum VerticalSwipeAction: Int, CaseIterable {
    case expand = 0
    case showWidgets = 1
    case none = 2

    var label: String {
        switch self {
        case .expand: "Expand Notch"
        case .showWidgets: "Show Widgets"
        case .none: "None"
        }
    }

    static var current: VerticalSwipeAction {
        let raw = UserDefaults.standard.integer(forKey: "gestureVerticalSwipe")
        return VerticalSwipeAction(rawValue: raw) ?? .expand
    }
}

enum LongPressAction: Int, CaseIterable {
    case showSettings = 0
    case showWidgetPicker = 1
    case none = 2

    var label: String {
        switch self {
        case .showSettings: "Show Settings"
        case .showWidgetPicker: "Show Widget Picker"
        case .none: "None"
        }
    }

    static var current: LongPressAction {
        let raw = UserDefaults.standard.integer(forKey: "gestureLongPress")
        return LongPressAction(rawValue: raw) ?? .showSettings
    }
}

extension Notification.Name {
    static let gestureSettingsDidChange = Notification.Name("gestureSettingsDidChange")
}
