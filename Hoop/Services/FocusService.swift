import Foundation
import Observation

@Observable
final class FocusService {

    var focusModeName: String?
    var isActive: Bool = false

    private var observer: NSObjectProtocol?

    func startObserving() {
        refreshFocusState()
        // Listen for Do Not Disturb / Focus Mode changes
        observer = DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.doNotDisturb"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshFocusState()
        }
    }

    func stopObserving() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
    }

    private func refreshFocusState() {
        // Check DND / Focus state via UserDefaults (shared domain)
        let dndDefaults = UserDefaults(suiteName: "com.apple.controlcenter")
        let isDND = dndDefaults?.bool(forKey: "NSStatusItem Visible DoNotDisturb") ?? false

        // Also check via assertion store (more reliable on newer macOS)
        let assertionStore = UserDefaults(suiteName: "com.apple.ncprefs")
        let dndEnabled = assertionStore?.bool(forKey: "dnd_prefs_enabled") ?? false

        let active = isDND || dndEnabled
        isActive = active
        focusModeName = active ? "Focus" : nil
    }
}
