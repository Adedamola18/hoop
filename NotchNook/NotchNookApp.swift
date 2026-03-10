import SwiftUI

@main
struct NotchNookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchNook", systemImage: "gearshape") {
            SettingsLink {
                Text("Settings...")
            }
            Divider()
            Button("Quit NotchNook") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
