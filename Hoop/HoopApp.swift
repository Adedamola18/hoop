import SwiftUI

@main
struct HoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Hoop", systemImage: "gearshape") {
            Button("About Hoop") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.orderFrontStandardAboutPanel(options: [
                    .applicationName: "Hoop",
                    .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                    .credits: NSAttributedString(string: "Your notch, upgraded.\nMedia controls, widgets, HUD & more.", attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ])
                ])
            }
            SettingsLink {
                Text("Settings...")
            }
            Divider()
            Button("Quit Hoop") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView(
                alertEngine: appDelegate.windowManager.alertEngine,
                securityGate: appDelegate.windowManager.securityGate,
                widgetRegistry: appDelegate.windowManager.widgetRegistry
            )
        }
    }
}
