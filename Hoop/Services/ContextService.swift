import AppKit
import Observation

/// Determines which widget to show based on frontmost app, time of day, and Focus Mode.
@Observable
final class ContextService {

    enum WidgetHint: String, CaseIterable, Codable {
        case media    // Show media player widget
        case none     // No contextual widget (use default)
    }

    // MARK: - Time-of-Day Profiles

    enum TimeProfile: String, CaseIterable, Codable, Identifiable {
        case morning
        case afternoon
        case evening

        var id: String { rawValue }

        var label: String {
            switch self {
            case .morning: "Morning"
            case .afternoon: "Afternoon"
            case .evening: "Evening"
            }
        }

        var defaultIcon: String {
            switch self {
            case .morning: "sunrise.fill"
            case .afternoon: "sun.max.fill"
            case .evening: "moon.stars.fill"
            }
        }
    }

    /// Widget assignment per time profile. Persisted in UserDefaults.
    struct TimeProfileConfig: Codable {
        var morningStartHour: Int = 6
        var afternoonStartHour: Int = 12
        var eveningStartHour: Int = 18
        var morningWidget: WidgetHint = .none
        var afternoonWidget: WidgetHint = .media
        var eveningWidget: WidgetHint = .media

        func widgetHint(for profile: TimeProfile) -> WidgetHint {
            switch profile {
            case .morning: return morningWidget
            case .afternoon: return afternoonWidget
            case .evening: return eveningWidget
            }
        }

        mutating func setWidgetHint(_ hint: WidgetHint, for profile: TimeProfile) {
            switch profile {
            case .morning: morningWidget = hint
            case .afternoon: afternoonWidget = hint
            case .evening: eveningWidget = hint
            }
        }

        func startHour(for profile: TimeProfile) -> Int {
            switch profile {
            case .morning: return morningStartHour
            case .afternoon: return afternoonStartHour
            case .evening: return eveningStartHour
            }
        }

        mutating func setStartHour(_ hour: Int, for profile: TimeProfile) {
            switch profile {
            case .morning: morningStartHour = hour
            case .afternoon: afternoonStartHour = hour
            case .evening: eveningStartHour = hour
            }
        }
    }

    // MARK: - Focus Mode

    /// Widget assignment per Focus Mode name. Persisted in UserDefaults.
    struct FocusModeConfig: Codable {
        /// Map from Focus Mode name (e.g., "Work", "Personal", "Do Not Disturb") to widget hint.
        var assignments: [String: WidgetHint] = [
            "Work": .none,
            "Personal": .media,
            "Do Not Disturb": .none,
        ]
    }

    // MARK: - Published State

    /// Bundle ID of the currently frontmost application.
    private(set) var frontmostBundleID: String?

    /// Display name of the currently frontmost application.
    private(set) var frontmostAppName: String?

    /// The widget hint derived from combined rules.
    private(set) var widgetHint: WidgetHint = .none

    /// Current time-of-day profile.
    private(set) var currentTimeProfile: TimeProfile = .morning

    /// Currently active Focus Mode name (nil if no Focus Mode active).
    private(set) var activeFocusMode: String?

    /// Whether a Focus Mode is currently active.
    private(set) var isFocusModeActive: Bool = false

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

    /// Whether time-of-day profiles are enabled.
    var timeProfilesEnabled: Bool {
        get {
            let v = UserDefaults.standard.object(forKey: "timeProfilesEnabled")
            return (v as? Bool) ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "timeProfilesEnabled")
            evaluateRules()
        }
    }

    /// Whether Focus Mode integration is enabled.
    var focusModeEnabled: Bool {
        get {
            let v = UserDefaults.standard.object(forKey: "focusModeEnabled")
            return (v as? Bool) ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "focusModeEnabled")
            evaluateRules()
        }
    }

    /// Time profile configuration. Persisted in UserDefaults.
    var timeProfileConfig: TimeProfileConfig {
        get {
            if let data = UserDefaults.standard.data(forKey: "timeProfileConfig"),
               let config = try? JSONDecoder().decode(TimeProfileConfig.self, from: data) {
                return config
            }
            return TimeProfileConfig()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "timeProfileConfig")
            }
            evaluateRules()
        }
    }

    /// Focus Mode configuration. Persisted in UserDefaults.
    var focusModeConfig: FocusModeConfig {
        get {
            if let data = UserDefaults.standard.data(forKey: "focusModeConfig"),
               let config = try? JSONDecoder().decode(FocusModeConfig.self, from: data) {
                return config
            }
            return FocusModeConfig()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "focusModeConfig")
            }
            evaluateRules()
        }
    }

    private var workspaceObserver: Any?
    private var focusObserver: Any?
    private var timeProfileTimer: Timer?

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

        // Observe Focus Mode changes via DistributedNotificationCenter
        focusObserver = DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.doNotDisturb"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateFocusMode()
        }

        // Initial focus mode check
        updateFocusMode()

        // Initial time profile
        updateTimeProfile()

        // Timer to re-evaluate time profile at the top of each hour
        scheduleTimeProfileTimer()
    }

    func stopObserving() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let observer = focusObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            focusObserver = nil
        }
        timeProfileTimer?.invalidate()
        timeProfileTimer = nil
    }

    // MARK: - Time Profile

    private func updateTimeProfile() {
        let hour = Calendar.current.component(.hour, from: Date())
        let config = timeProfileConfig

        // Determine profile based on hour boundaries (evening -> afternoon -> morning)
        if hour >= config.eveningStartHour {
            currentTimeProfile = .evening
        } else if hour >= config.afternoonStartHour {
            currentTimeProfile = .afternoon
        } else if hour >= config.morningStartHour {
            currentTimeProfile = .morning
        } else {
            // Before morning start (e.g., 0-5am) — treat as evening (previous day)
            currentTimeProfile = .evening
        }
        evaluateRules()
    }

    private func scheduleTimeProfileTimer() {
        timeProfileTimer?.invalidate()
        // Schedule to fire at the next hour boundary (+5s buffer), then re-schedule.
        // Much more efficient than polling every 60s — fires ~24 times/day instead of ~1440.
        let calendar = Calendar.current
        let now = Date()
        if let nextHour = calendar.nextDate(after: now, matching: DateComponents(minute: 0, second: 5), matchingPolicy: .nextTime) {
            let interval = nextHour.timeIntervalSince(now)
            timeProfileTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 1), repeats: false) { [weak self] _ in
                self?.updateTimeProfile()
                self?.scheduleTimeProfileTimer() // Re-schedule for next hour
            }
        } else {
            // Fallback: fire every 5 minutes
            timeProfileTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                self?.updateTimeProfile()
            }
        }
    }

    // MARK: - Focus Mode

    private func updateFocusMode() {
        // Read Focus/DND state from the system preferences.
        // On macOS 14+, Focus Mode state can be read from the assertions store.
        // Best-effort: check if Do Not Disturb / Focus is active via user defaults.
        let dndDefaults = UserDefaults(suiteName: "com.apple.controlcenter")
        let focusDefaults = UserDefaults(suiteName: "com.apple.focus.state")

        // Try to read Focus Mode name from focus state plist
        if let storeData = focusDefaults?.dictionary(forKey: "Current"),
           let name = storeData["name"] as? String {
            activeFocusMode = name
            isFocusModeActive = true
        } else if let dndEnabled = dndDefaults?.object(forKey: "NSStatusItem Visible DoNotDisturb") as? Bool, dndEnabled {
            activeFocusMode = "Do Not Disturb"
            isFocusModeActive = true
        } else {
            // Fallback: check via assertionStore (macOS Sonoma+)
            let assertionDefaults = UserDefaults(suiteName: "com.apple.FocusState")
            if let modes = assertionDefaults?.array(forKey: "FocusConfigurations") as? [[String: Any]],
               let activeMode = modes.first(where: { ($0["active"] as? Bool) == true }),
               let name = activeMode["name"] as? String {
                activeFocusMode = name
                isFocusModeActive = true
            } else {
                activeFocusMode = nil
                isFocusModeActive = false
            }
        }
        evaluateRules()
    }

    // MARK: - Evaluation

    private func updateFrontmostApp(_ app: NSRunningApplication?) {
        frontmostBundleID = app?.bundleIdentifier
        frontmostAppName = app?.localizedName
        evaluateRules()
    }

    /// User-defined custom context rules. Persisted via ContextRuleStore.
    var customRules: [ContextRule] {
        get { ContextRuleStore.load() }
        set {
            ContextRuleStore.save(newValue)
            evaluateRules()
        }
    }

    private func evaluateRules() {
        guard isEnabled else {
            widgetHint = .none
            return
        }

        // Priority 0: Custom user rules (first match wins)
        let rules = ContextRuleStore.load()
        for rule in rules {
            if rule.matches(frontmostBundleID: frontmostBundleID, timeProfile: currentTimeProfile, activeFocusMode: activeFocusMode) {
                widgetHint = rule.widgetHint
                return
            }
        }

        // Priority 1: Focus Mode override (if enabled and active)
        if focusModeEnabled, isFocusModeActive, let focusName = activeFocusMode {
            let config = focusModeConfig
            if let hint = config.assignments[focusName] {
                widgetHint = hint
                return
            }
        }

        // Priority 2: Time-of-day profile (if enabled)
        if timeProfilesEnabled {
            let config = timeProfileConfig
            let profileHint = config.widgetHint(for: currentTimeProfile)
            // If time profile says .none, still allow app-based override
            if profileHint != .none {
                widgetHint = profileHint
                return
            }
        }

        // Priority 3: Frontmost app matching
        if let bundleID = frontmostBundleID, mediaAppBundleIDs.contains(bundleID) {
            widgetHint = .media
        } else {
            widgetHint = .none
        }
    }
}
