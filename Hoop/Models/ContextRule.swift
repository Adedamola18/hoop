import Foundation

/// A user-defined context rule: condition + widget action pair.
/// Rules are evaluated in priority order (array index); first match wins.
struct ContextRule: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var condition: RuleCondition
    var widgetHint: ContextService.WidgetHint
    var isEnabled: Bool = true

    enum ConditionType: String, Codable, CaseIterable {
        case app = "app"
        case time = "time"
        case focus = "focus"

        var label: String {
            switch self {
            case .app: "App is frontmost"
            case .time: "Time of day is"
            case .focus: "Focus Mode is"
            }
        }
    }

    enum RuleCondition: Codable {
        case app(bundleID: String)
        case time(profile: ContextService.TimeProfile)
        case focus(modeName: String)

        var conditionType: ConditionType {
            switch self {
            case .app: return .app
            case .time: return .time
            case .focus: return .focus
            }
        }

        var displayValue: String {
            switch self {
            case .app(let bundleID): return bundleID
            case .time(let profile): return profile.label
            case .focus(let name): return name
            }
        }
    }

    /// Evaluate whether this rule matches the current context.
    func matches(frontmostBundleID: String?, timeProfile: ContextService.TimeProfile, activeFocusMode: String?) -> Bool {
        guard isEnabled else { return false }
        switch condition {
        case .app(let bundleID):
            return frontmostBundleID == bundleID
        case .time(let profile):
            return timeProfile == profile
        case .focus(let modeName):
            return activeFocusMode == modeName
        }
    }
}

/// Persistence helper for context rules with in-memory cache.
enum ContextRuleStore {
    private static let key = "contextRules"
    private static var cachedRules: [ContextRule]?

    static func load() -> [ContextRule] {
        if let cached = cachedRules { return cached }
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode([ContextRule].self, from: data) else {
            cachedRules = []
            return []
        }
        cachedRules = rules
        return rules
    }

    static func save(_ rules: [ContextRule]) {
        cachedRules = rules
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func invalidateCache() {
        cachedRules = nil
    }
}