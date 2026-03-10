import Foundation
import Observation

@Observable
final class WidgetRegistry {

    /// All registered widgets (order determines display order).
    private(set) var widgets: [any NotchWidget] = []

    /// IDs of widgets the user has enabled, in display order.
    var enabledWidgetIDs: [String] {
        didSet {
            UserDefaults.standard.set(enabledWidgetIDs, forKey: "enabledWidgetIDs")
        }
    }

    /// Enabled widgets in display order.
    var enabledWidgets: [any NotchWidget] {
        enabledWidgetIDs.compactMap { id in
            widgets.first { $0.id == id }
        }
    }

    init() {
        enabledWidgetIDs = UserDefaults.standard.stringArray(forKey: "enabledWidgetIDs") ?? []
    }

    /// Register a widget. If no enabled list exists yet, enable it by default.
    func register(_ widget: any NotchWidget) {
        guard !widgets.contains(where: { $0.id == widget.id }) else { return }
        widgets.append(widget)

        // First-time: enable all registered widgets by default
        if UserDefaults.standard.stringArray(forKey: "enabledWidgetIDs") == nil {
            enabledWidgetIDs = widgets.map(\.id)
        }
    }

    func isEnabled(_ id: String) -> Bool {
        enabledWidgetIDs.contains(id)
    }

    func setEnabled(_ id: String, enabled: Bool) {
        if enabled {
            if !enabledWidgetIDs.contains(id) {
                enabledWidgetIDs.append(id)
            }
        } else {
            enabledWidgetIDs.removeAll { $0 == id }
        }
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        enabledWidgetIDs.move(fromOffsets: source, toOffset: destination)
    }
}
