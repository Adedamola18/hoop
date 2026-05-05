import SwiftUI
import AppKit

@main
struct HoopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Hoop", systemImage: "gearshape") {
            Button("About Hoop") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                var options: [NSApplication.AboutPanelOptionKey: Any] = [
                    .applicationName: "Hoop",
                    .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                    .credits: NSAttributedString(string: "Your notch, upgraded.\nMedia controls, widgets, HUD & more.", attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ])
                ]
                if let icon = NSImage(named: "AppIcon") ?? NSImage(named: NSImage.applicationIconName) {
                    options[.applicationIcon] = icon
                }
                NSApplication.shared.orderFrontStandardAboutPanel(options: options)
            }
            SettingsMenuButton()
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

/// Settings menu button that opens the Settings scene via SwiftUI's environment
/// action (the same one `SettingsLink` uses), then applies a `canJoinAllSpaces`
/// flicker so the window jumps to the user's current Space instead of staying
/// on whichever Space it was last shown on.
private struct SettingsMenuButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings...") {
            // Promote to a regular app temporarily so the Settings window opens as a
            // proper standalone window (Cmd+Tab, Mission Control, etc.) instead of an
            // LSUIElement-style floating overlay. AppDelegate reverts to .accessory
            // once the window closes.
            NSApp.setActivationPolicy(.regular)
            if #available(macOS 14, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            openSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                bringSettingsToCurrentSpace()
            }
        }
    }
}

private func bringSettingsToCurrentSpace() {
    if #available(macOS 14, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }

    guard let window = NSApp.windows.first(where: isLikelySettingsWindow) else { return }

    // Phase 1: briefly let the window join every Space so it materializes here.
    window.collectionBehavior = [.canJoinAllSpaces]
    window.orderFrontRegardless()

    // Phase 2: revert to a normal window that follows the user across Spaces.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        window.collectionBehavior = [.moveToActiveSpace]
        window.makeKeyAndOrderFront(nil)
    }
}

private func isLikelySettingsWindow(_ window: NSWindow) -> Bool {
    if window is NotchPanel { return false }
    let className = String(describing: type(of: window))
    if className.contains("AboutWindow") || className.contains("StatusBar") { return false }
    if let id = window.identifier?.rawValue, id.contains("Settings") { return true }
    if window.title.localizedCaseInsensitiveContains("settings") { return true }
    if window.title.localizedCaseInsensitiveContains("preferences") { return true }
    return false
}
