import SwiftUI

@main
struct HoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Hoop", systemImage: "gearshape") {
            SettingsLink {
                Text("Settings...")
            }
            Divider()
            Button("Quit Hoop") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
