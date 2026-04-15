import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowManager: NotchWindowManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = NotchWindowManager()
    }
}
