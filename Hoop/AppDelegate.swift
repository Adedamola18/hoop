import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: NotchWindowManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = NotchWindowManager()
    }
}
