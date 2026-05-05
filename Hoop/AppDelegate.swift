import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = NotchWindowManager()
    private var settingsWindowObserver: NSObjectProtocol?
    private var settingsWindowCloseObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The Settings window otherwise stays on whichever Space it was last opened on,
        // making the user swipe across Spaces to find it. Mark it as following the
        // active Space so reopening it always brings it to the user.
        settingsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  AppDelegate.isSettingsWindow(window) else { return }
            window.collectionBehavior.insert(.moveToActiveSpace)
        }

        // While Settings is open we run as a regular app (dock icon, Cmd+Tab, real
        // window). When the user closes it, drop back to .accessory so the dock icon
        // disappears and Hoop returns to being a pure menu-bar app.
        settingsWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow,
                  AppDelegate.isSettingsWindow(window) else { return }
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    deinit {
        if let observer = settingsWindowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = settingsWindowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window is NotchPanel { return false }
        if let identifier = window.identifier?.rawValue, identifier.contains("Settings") {
            return true
        }
        return window.title.localizedCaseInsensitiveContains("Settings")
    }
}