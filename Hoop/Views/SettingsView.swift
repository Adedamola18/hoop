import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            HUDSettingsTab()
                .tabItem {
                    Label("HUD", systemImage: "slider.horizontal.3")
                }
            ContextSettingsTab()
                .tabItem {
                    Label("Context", systemImage: "app.connected.to.app.below.fill")
                }
        }
        .frame(width: 450, height: 350)
    }
}

struct HUDSettingsTab: View {
    @State private var hudReplacementEnabled: Bool = {
        let v = UserDefaults.standard.object(forKey: "hudReplacementEnabled")
        return (v as? Bool) ?? true
    }()
    @State private var autoDismissTimeout: Double = {
        let t = UserDefaults.standard.double(forKey: "hudDismissTimeout")
        return t > 0 ? max(1, min(5, t)) : 2
    }()

    var body: some View {
        Form {
            Section("HUD Replacement") {
                Toggle("Replace system volume & brightness HUD", isOn: $hudReplacementEnabled)
                    .onChange(of: hudReplacementEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "hudReplacementEnabled")
                        NotificationCenter.default.post(name: .hudSettingsDidChange, object: nil)
                    }

                if hudReplacementEnabled {
                    Text("Shows a slim slider inside the notch instead of the native macOS HUD. Requires Accessibility permission for suppression.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Auto-Dismiss") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Timeout")
                        Spacer()
                        Text(String(format: "%.1fs", autoDismissTimeout))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $autoDismissTimeout, in: 1...5, step: 0.5)
                        .onChange(of: autoDismissTimeout) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "hudDismissTimeout")
                        }
                }
            }
        }
        .padding()
    }
}

struct GeneralSettingsTab: View {
    @State private var activationTrigger: ActivationTrigger = .current
    @State private var hoverDelayMs: Double = {
        let ms = UserDefaults.standard.double(forKey: "hoverDwellDelayMs")
        return ms > 0 ? ms : 200
    }()
    @State private var hotkeyModifierFlags: Int = {
        let v = UserDefaults.standard.object(forKey: "hotkeyModifierFlags")
        return (v as? Int) ?? Int(NSEvent.ModifierFlags.option.rawValue)
    }()
    @State private var hotkeyKeyCode: Int = {
        let v = UserDefaults.standard.object(forKey: "hotkeyKeyCode")
        return (v as? Int) ?? Int(kVK_ANSI_N)
    }()
    @State private var isRecordingHotkey = false

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLoginToggle()
            }

            Section("Activation") {
                Picker("Trigger", selection: $activationTrigger) {
                    ForEach(ActivationTrigger.allCases, id: \.self) { trigger in
                        Text(trigger.label).tag(trigger)
                    }
                }
                .onChange(of: activationTrigger) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "activationTrigger")
                    NotificationCenter.default.post(name: .activationTriggerDidChange, object: nil)
                }

                if activationTrigger == .hover {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Hover delay")
                            Spacer()
                            Text("\(Int(hoverDelayMs))ms")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $hoverDelayMs, in: 100...500, step: 50)
                            .onChange(of: hoverDelayMs) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "hoverDwellDelayMs")
                            }
                    }
                }

                if activationTrigger == .hotkey {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        Button(action: { isRecordingHotkey = true }) {
                            Text(isRecordingHotkey ? "Press shortcut…" : hotkeyDisplayString)
                                .frame(minWidth: 120)
                        }
                        .onKeyPress { keyPress in
                            guard isRecordingHotkey else { return .ignored }
                            // Map SwiftUI EventModifiers to NSEvent.ModifierFlags
                            var flags: NSEvent.ModifierFlags = []
                            if keyPress.modifiers.contains(.command) { flags.insert(.command) }
                            if keyPress.modifiers.contains(.option) { flags.insert(.option) }
                            if keyPress.modifiers.contains(.control) { flags.insert(.control) }
                            if keyPress.modifiers.contains(.shift) { flags.insert(.shift) }

                            guard !flags.isEmpty else { return .ignored }

                            // Use Carbon key code from the key's character
                            let charCode = keyCodeFromCharacter(keyPress.characters)
                            hotkeyKeyCode = charCode
                            hotkeyModifierFlags = Int(flags.rawValue)
                            UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
                            UserDefaults.standard.set(hotkeyModifierFlags, forKey: "hotkeyModifierFlags")
                            isRecordingHotkey = false
                            NotificationCenter.default.post(name: .activationTriggerDidChange, object: nil)
                            return .handled
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var hotkeyDisplayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(hotkeyModifierFlags))
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(stringFromKeyCode(hotkeyKeyCode))
        return parts.joined()
    }

    private func stringFromKeyCode(_ keyCode: Int) -> String {
        let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
        guard let layoutDataRef = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return String(UnicodeScalar(UInt8(keyCode + 65)))
        }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self) as Data
        return layoutData.withUnsafeBytes { rawBuf -> String in
            guard let ptr = rawBuf.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return "?"
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length: Int = 0
            UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }

    private func keyCodeFromCharacter(_ chars: String) -> Int {
        let charToKeyCode: [Character: Int] = [
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        ]
        guard let first = chars.lowercased().first else { return kVK_ANSI_N }
        return charToKeyCode[first] ?? kVK_ANSI_N
    }
}

struct ContextSettingsTab: View {
    @State private var contextSwitchingEnabled: Bool = {
        let v = UserDefaults.standard.object(forKey: "contextSwitchingEnabled")
        return (v as? Bool) ?? true
    }()
    @State private var mediaApps: String = {
        if let stored = UserDefaults.standard.array(forKey: "contextMediaAppBundleIDs") as? [String] {
            return stored.sorted().joined(separator: "\n")
        }
        return ContextService.defaultMediaAppBundleIDs.sorted().joined(separator: "\n")
    }()

    var body: some View {
        Form {
            Section("Widget Switching") {
                Toggle("Auto-switch widgets based on frontmost app", isOn: $contextSwitchingEnabled)
                    .onChange(of: contextSwitchingEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "contextSwitchingEnabled")
                    }

                if contextSwitchingEnabled {
                    Text("When a media app is frontmost, the media widget is shown in the expanded notch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if contextSwitchingEnabled {
                Section("Media App Bundle IDs") {
                    TextEditor(text: $mediaApps)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 100)
                        .onChange(of: mediaApps) { _, newValue in
                            let ids = newValue
                                .split(separator: "\n")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            UserDefaults.standard.set(ids, forKey: "contextMediaAppBundleIDs")
                        }

                    Button("Reset to Defaults") {
                        let defaults = ContextService.defaultMediaAppBundleIDs.sorted()
                        mediaApps = defaults.joined(separator: "\n")
                        UserDefaults.standard.set(defaults, forKey: "contextMediaAppBundleIDs")
                    }
                    .controlSize(.small)
                }
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
