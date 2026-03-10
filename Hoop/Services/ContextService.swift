import AppKit
import Observation

/// Determines which widget to show based on frontmost app and built-in rules.
@Observable
final class ContextService {

    enum WidgetHint: String, CaseIterable, Codable {
        case media    // Show media player widget
        case none     // No contextual widget (use default)
    }

    /// Bundle ID of the currently frontmost application.
    private(set) var frontmostBundleID: String?

    /// Display name of the currently frontmost application.
    private(set) var frontmostAppName: String?

    /// The widget hint derived from the frontmost app + rules.
    private(set) var widgetHint: WidgetHint = .none

    /// Built-in media app bundle IDs that trigger the media widget.
    static let defaultMediaAppBundleIDs: Set<String> = [
        "com.spotify.client",
        "com.apple.Music",
        "com.apple.iTunes",
        "com.tidal.desktop",
        "com.amazon.music",
        "com.soundcloud.desktop",
        "tv.plex.plexamp",
        "com.ciderapp.Cider",
    ]

    /// User-configured media app bundle IDs. Persisted in UserDefaults.
    var mediaAppBundleIDs: Set<String> {
        get {
            if let stored = UserDefaults.standard.array(forKey: "contextMediaAppBundleIDs") as? [String] {
                return Set(stored)
            }
            return Self.defaultMediaAppBundleIDs
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "contextMediaAppBundleIDs")
            evaluateRules()
        }
    }

    /// Whether context-aware widget switching is enabled.
    var isEnabled: Bool {
        get {
            let v = UserDefaults.standard.object(forKey: "contextSwitchingEnabled")
            return (v as? Bool) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "contextSwitchingEnabled")
            evaluateRules()
        }
    }

    private var workspaceObserver: Any?

    // MARK: - Lifecycle

    func startObserving() {
        // Read initial frontmost app
        updateFrontmostApp(NSWorkspace.shared.frontmostApplication)

        // Observe app activation changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.updateFrontmostApp(app)
        }
    }

    func stopObserving() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
    }

    // MARK: - Evaluation

    private func updateFrontmostApp(_ app: NSRunningApplication?) {
        frontmostBundleID = app?.bundleIdentifier
        frontmostAppName = app?.localizedName
        evaluateRules()
    }

    private func evaluateRules() {
        guard isEnabled, let bundleID = frontmostBundleID else {
            widgetHint = .none
            return
        }

        if mediaAppBundleIDs.contains(bundleID) {
            widgetHint = .media
        } else {
            widgetHint = .none
        }
    }
}
