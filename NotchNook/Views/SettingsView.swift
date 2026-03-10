import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsTab: View {
    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLoginToggle()
            }
        }
        .padding()
    }
}

struct LaunchAtLoginToggle: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Revert toggle on failure -- always read from SMAppService as source of truth
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
            .onAppear {
                // Sync with system state (user may have toggled in System Settings)
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
    }
}
