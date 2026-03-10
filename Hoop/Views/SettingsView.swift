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
            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            HUDSettingsTab()
                .tabItem {
                    Label("HUD", systemImage: "slider.horizontal.3")
                }
            WidgetsSettingsTab()
                .tabItem {
                    Label("Widgets", systemImage: "square.grid.2x2")
                }
            ContextSettingsTab()
                .tabItem {
                    Label("Context", systemImage: "app.connected.to.app.below.fill")
                }
            DropActionsSettingsTab()
                .tabItem {
                    Label("Drop Actions", systemImage: "arrow.down.doc")
                }
        }
        .frame(width: 500, height: 500)
    }
}

struct AppearanceSettingsTab: View {
    @State private var selectedTheme: ThemeMode = ThemeMode.current

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $selectedTheme) {
                    ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: selectedTheme) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "themeMode")
                    NotificationCenter.default.post(name: .themeModeDidChange, object: nil)
                }

                Text("Solid Dark matches the hardware notch. Translucent adds a frosted overlay. Liquid Glass uses a lighter frosted effect.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct WidgetsSettingsTab: View {
    @State private var enabledIDs: Set<String> = {
        if let stored = UserDefaults.standard.array(forKey: "enabledWidgetIDs") as? [String] {
            return Set(stored)
        }
        return []
    }()
    @State private var widgetOrder: [String] = {
        UserDefaults.standard.stringArray(forKey: "widgetOrder") ?? []
    }()

    private let allWidgets: [(id: String, name: String, icon: String)] = [
        ("calendar", "Calendar", "calendar"),
        ("timer", "Timer & Stopwatch", "timer"),
        ("clipboard", "Clipboard History", "doc.on.clipboard"),
        ("shortcuts", "Shortcuts", "shortcuts"),
        ("notes", "Quick Notes", "note.text"),
        ("colorpicker", "Color Picker", "eyedropper"),
        ("converter", "Unit Converter", "arrow.left.arrow.right"),
        ("webcam", "Webcam Preview", "web.camera"),
        ("systemstats", "System Stats", "gauge.with.dots.needle.bottom.50percent"),
    ]

    var body: some View {
        Form {
            Section("Enabled Widgets") {
                Text("Toggle widgets on or off. Drag to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(allWidgets, id: \.id) { widget in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { enabledIDs.contains(widget.id) },
                            set: { newValue in
                                if newValue {
                                    enabledIDs.insert(widget.id)
                                } else {
                                    enabledIDs.remove(widget.id)
                                }
                                UserDefaults.standard.set(Array(enabledIDs), forKey: "enabledWidgetIDs")
                            }
                        )) {
                            Label(widget.name, systemImage: widget.icon)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
    @State private var expandedWidth: Double = {
        let w = UserDefaults.standard.double(forKey: "expandedWidth")
        return w > 0 ? max(400, min(800, w)) : 600
    }()
    @State private var expandedHeight: Double = {
        let h = UserDefaults.standard.double(forKey: "expandedHeight")
        return h > 0 ? max(150, min(400, h)) : 200
    }()
    @State private var contentPadding: Double = {
        let p = UserDefaults.standard.double(forKey: "contentPadding")
        return p > 0 ? max(8, min(32, p)) : 16
    }()
    @State private var horizontalSwipe: HorizontalSwipeAction = .current
    @State private var verticalSwipe: VerticalSwipeAction = .current
    @State private var longPress: LongPressAction = .current

    var body: some View {
        ScrollView {
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

            Section("Expanded Size") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Width")
                        Spacer()
                        Text("\(Int(expandedWidth))pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $expandedWidth, in: 400...800, step: 25)
                        .onChange(of: expandedWidth) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "expandedWidth")
                        }
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Height")
                        Spacer()
                        Text("\(Int(expandedHeight))pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $expandedHeight, in: 150...400, step: 25)
                        .onChange(of: expandedHeight) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "expandedHeight")
                        }
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Content Padding")
                        Spacer()
                        Text("\(Int(contentPadding))pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $contentPadding, in: 8...32, step: 2)
                        .onChange(of: contentPadding) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "contentPadding")
                        }
                }
            }

            Section("Gestures") {
                Picker("Horizontal Swipe", selection: $horizontalSwipe) {
                    ForEach(HorizontalSwipeAction.allCases, id: \.self) { action in
                        Text(action.label).tag(action)
                    }
                }
                .onChange(of: horizontalSwipe) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "gestureHorizontalSwipe")
                }

                Picker("Swipe Down", selection: $verticalSwipe) {
                    ForEach(VerticalSwipeAction.allCases, id: \.self) { action in
                        Text(action.label).tag(action)
                    }
                }
                .onChange(of: verticalSwipe) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "gestureVerticalSwipe")
                }

                Picker("Long Press", selection: $longPress) {
                    ForEach(LongPressAction.allCases, id: \.self) { action in
                        Text(action.label).tag(action)
                    }
                }
                .onChange(of: longPress) { _, newValue in
                    UserDefaults.standard.set(newValue.rawValue, forKey: "gestureLongPress")
                }
            }
        }
        .padding()
        }
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
    @State private var timeProfilesEnabled: Bool = {
        let v = UserDefaults.standard.object(forKey: "timeProfilesEnabled")
        return (v as? Bool) ?? false
    }()
    @State private var focusModeEnabled: Bool = {
        let v = UserDefaults.standard.object(forKey: "focusModeEnabled")
        return (v as? Bool) ?? false
    }()
    @State private var timeConfig: ContextService.TimeProfileConfig = {
        if let data = UserDefaults.standard.data(forKey: "timeProfileConfig"),
           let config = try? JSONDecoder().decode(ContextService.TimeProfileConfig.self, from: data) {
            return config
        }
        return ContextService.TimeProfileConfig()
    }()
    @State private var focusConfig: ContextService.FocusModeConfig = {
        if let data = UserDefaults.standard.data(forKey: "focusModeConfig"),
           let config = try? JSONDecoder().decode(ContextService.FocusModeConfig.self, from: data) {
            return config
        }
        return ContextService.FocusModeConfig()
    }()
    @State private var newFocusModeName: String = ""
    @State private var customRules: [ContextRule] = ContextRuleStore.load()
    @State private var showingAddRule = false

    var body: some View {
        ScrollView {
            Form {
                // MARK: - Custom Rules
                Section("Custom Rules") {
                    Text("Rules are evaluated in order. First matching rule wins, overriding all other settings below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(Array(customRules.enumerated()), id: \.element.id) { index, rule in
                        HStack {
                            Toggle("", isOn: Binding(
                                get: { customRules[index].isEnabled },
                                set: { newValue in
                                    customRules[index].isEnabled = newValue
                                    saveCustomRules()
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.checkbox)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.name)
                                    .font(.body)
                                Text("When \(rule.condition.conditionType.label.lowercased()) \(rule.condition.displayValue) → \(rule.widgetHint.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                moveRuleUp(index)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                moveRuleDown(index)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == customRules.count - 1)

                            Button(role: .destructive) {
                                customRules.remove(at: index)
                                saveCustomRules()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Rule…") {
                        showingAddRule = true
                    }
                    .controlSize(.small)
                    .sheet(isPresented: $showingAddRule) {
                        AddContextRuleSheet { newRule in
                            customRules.append(newRule)
                            saveCustomRules()
                        }
                    }
                }

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
                            .frame(height: 80)
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

                // MARK: - Time-of-Day Profiles

                Section("Time-of-Day Profiles") {
                    Toggle("Enable time-based widget profiles", isOn: $timeProfilesEnabled)
                        .onChange(of: timeProfilesEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "timeProfilesEnabled")
                        }

                    if timeProfilesEnabled {
                        Text("Widgets change based on the time of day. Focus Mode overrides take priority.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(ContextService.TimeProfile.allCases) { profile in
                            HStack {
                                Image(systemName: profile.defaultIcon)
                                    .frame(width: 20)
                                Text(profile.label)

                                Spacer()

                                Picker("Start", selection: Binding(
                                    get: { timeConfig.startHour(for: profile) },
                                    set: { newHour in
                                        timeConfig.setStartHour(newHour, for: profile)
                                        saveTimeConfig()
                                    }
                                )) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(formatHour(hour)).tag(hour)
                                    }
                                }
                                .frame(width: 90)

                                Picker("Widget", selection: Binding(
                                    get: { timeConfig.widgetHint(for: profile) },
                                    set: { newHint in
                                        timeConfig.setWidgetHint(newHint, for: profile)
                                        saveTimeConfig()
                                    }
                                )) {
                                    ForEach(ContextService.WidgetHint.allCases, id: \.self) { hint in
                                        Text(hint.rawValue.capitalized).tag(hint)
                                    }
                                }
                                .frame(width: 90)
                            }
                        }
                    }
                }

                // MARK: - Focus Mode Integration

                Section("Focus Mode") {
                    Toggle("Override widgets based on active Focus Mode", isOn: $focusModeEnabled)
                        .onChange(of: focusModeEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "focusModeEnabled")
                        }

                    if focusModeEnabled {
                        Text("When a macOS Focus Mode is active, the assigned widget is shown instead of the default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(Array(focusConfig.assignments.keys.sorted()), id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                Picker("Widget", selection: Binding(
                                    get: { focusConfig.assignments[name] ?? .none },
                                    set: { newHint in
                                        focusConfig.assignments[name] = newHint
                                        saveFocusConfig()
                                    }
                                )) {
                                    ForEach(ContextService.WidgetHint.allCases, id: \.self) { hint in
                                        Text(hint.rawValue.capitalized).tag(hint)
                                    }
                                }
                                .frame(width: 90)

                                Button(role: .destructive) {
                                    focusConfig.assignments.removeValue(forKey: name)
                                    saveFocusConfig()
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        HStack {
                            TextField("Focus Mode name", text: $newFocusModeName)
                                .textFieldStyle(.roundedBorder)
                            Button("Add") {
                                let name = newFocusModeName.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty else { return }
                                focusConfig.assignments[name] = ContextService.WidgetHint.none
                                saveFocusConfig()
                                newFocusModeName = ""
                            }
                            .disabled(newFocusModeName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func saveCustomRules() {
        ContextRuleStore.save(customRules)
    }

    private func moveRuleUp(_ index: Int) {
        guard index > 0 else { return }
        customRules.swapAt(index, index - 1)
        saveCustomRules()
    }

    private func moveRuleDown(_ index: Int) {
        guard index < customRules.count - 1 else { return }
        customRules.swapAt(index, index + 1)
        saveCustomRules()
    }

    private func saveTimeConfig() {
        if let data = try? JSONEncoder().encode(timeConfig) {
            UserDefaults.standard.set(data, forKey: "timeProfileConfig")
        }
    }

    private func saveFocusConfig() {
        if let data = try? JSONEncoder().encode(focusConfig) {
            UserDefaults.standard.set(data, forKey: "focusModeConfig")
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

struct AddContextRuleSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (ContextRule) -> Void

    @State private var ruleName = ""
    @State private var conditionType: ContextRule.ConditionType = .app
    @State private var appBundleID = ""
    @State private var timeProfile: ContextService.TimeProfile = .morning
    @State private var focusModeName = ""
    @State private var widgetHint: ContextService.WidgetHint = .media

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Context Rule")
                .font(.headline)

            Form {
                TextField("Rule name", text: $ruleName)

                Picker("When", selection: $conditionType) {
                    ForEach(ContextRule.ConditionType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }

                switch conditionType {
                case .app:
                    TextField("App bundle ID (e.g., com.apple.Xcode)", text: $appBundleID)
                case .time:
                    Picker("Time profile", selection: $timeProfile) {
                        ForEach(ContextService.TimeProfile.allCases) { profile in
                            Text(profile.label).tag(profile)
                        }
                    }
                case .focus:
                    TextField("Focus Mode name (e.g., Work)", text: $focusModeName)
                }

                Picker("Show widget", selection: $widgetHint) {
                    ForEach(ContextService.WidgetHint.allCases, id: \.self) { hint in
                        Text(hint.rawValue.capitalized).tag(hint)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    let condition: ContextRule.RuleCondition
                    switch conditionType {
                    case .app:
                        condition = .app(bundleID: appBundleID.trimmingCharacters(in: .whitespaces))
                    case .time:
                        condition = .time(profile: timeProfile)
                    case .focus:
                        condition = .focus(modeName: focusModeName.trimmingCharacters(in: .whitespaces))
                    }

                    let rule = ContextRule(
                        name: ruleName.trimmingCharacters(in: .whitespaces),
                        condition: condition,
                        widgetHint: widgetHint
                    )
                    onAdd(rule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 380)
    }

    private var isValid: Bool {
        guard !ruleName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch conditionType {
        case .app:
            return !appBundleID.trimmingCharacters(in: .whitespaces).isEmpty
        case .time:
            return true
        case .focus:
            return !focusModeName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

// MARK: - Drop Actions Settings Tab

struct DropActionsSettingsTab: View {
    @State private var customActions: [CustomDropActionConfig] = CustomDropActionStore.load()
    @State private var pipelines: [PipelineConfig] = PipelineStore.load()
    @State private var showingAddAction = false
    @State private var showingAddPipeline = false
    @State private var editingAction: CustomDropActionConfig? = nil
    @State private var editingPipeline: PipelineConfig? = nil

    var body: some View {
        ScrollView {
            Form {
                // MARK: Built-in Actions
                Section("Built-in Actions") {
                    HStack {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text("Compress Image")
                            Text("png, jpg, jpeg, tiff, bmp, heic, webp")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Image(systemName: "doc.text.viewfinder")
                            .frame(width: 20)
                        VStack(alignment: .leading) {
                            Text("Extract Text (OCR)")
                            Text("png, jpg, jpeg, tiff, bmp, heic, webp, pdf")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Custom Actions
                Section("Custom Actions") {
                    if customActions.isEmpty {
                        Text("No custom actions configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(customActions.enumerated()), id: \.element.id) { index, action in
                        HStack {
                            Image(systemName: action.actionType.iconName)
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(action.name)
                                Text("\(action.actionType.label) · \(extensionsLabel(action.fileExtensions))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Button {
                                editingAction = customActions[index]
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                customActions.remove(at: index)
                                CustomDropActionStore.save(customActions)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Action…") {
                        showingAddAction = true
                    }
                    .controlSize(.small)
                    .sheet(isPresented: $showingAddAction) {
                        AddDropActionSheet { newAction in
                            customActions.append(newAction)
                            CustomDropActionStore.save(customActions)
                        }
                    }
                    .sheet(item: $editingAction) { action in
                        EditDropActionSheet(action: action) { updated in
                            if let idx = customActions.firstIndex(where: { $0.id == updated.id }) {
                                customActions[idx] = updated
                                CustomDropActionStore.save(customActions)
                            }
                        }
                    }
                }

                // MARK: Pipelines
                Section("Pipelines") {
                    Text("Chain multiple actions sequentially. Output from each step feeds into the next.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if pipelines.isEmpty {
                        Text("No pipelines configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(pipelines.enumerated()), id: \.element.id) { index, pipeline in
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .frame(width: 20)
                            VStack(alignment: .leading) {
                                Text(pipeline.name)
                                Text("\(pipeline.steps.count) step\(pipeline.steps.count == 1 ? "" : "s") · \(extensionsLabel(pipeline.supportedExtensions))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Button {
                                editingPipeline = pipelines[index]
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                pipelines.remove(at: index)
                                PipelineStore.save(pipelines)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Pipeline…") {
                        showingAddPipeline = true
                    }
                    .controlSize(.small)
                    .sheet(isPresented: $showingAddPipeline) {
                        EditPipelineSheet(pipeline: nil) { newPipeline in
                            pipelines.append(newPipeline)
                            PipelineStore.save(pipelines)
                        }
                    }
                    .sheet(item: $editingPipeline) { pipeline in
                        EditPipelineSheet(pipeline: pipeline) { updated in
                            if let idx = pipelines.firstIndex(where: { $0.id == updated.id }) {
                                pipelines[idx] = updated
                                PipelineStore.save(pipelines)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func extensionsLabel(_ exts: Set<String>) -> String {
        exts.contains("*") ? "Any file" : exts.sorted().joined(separator: ", ")
    }
}

// MARK: - Add Drop Action Sheet

struct AddDropActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (CustomDropActionConfig) -> Void

    @State private var name = ""
    @State private var actionType: CustomDropActionType = .shortcut
    @State private var config = ""
    @State private var fileExtensions = "*"

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Drop Action")
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                Picker("Type", selection: $actionType) {
                    ForEach(CustomDropActionType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }

                switch actionType {
                case .shortcut:
                    TextField("Shortcut name", text: $config)
                        .textFieldStyle(.roundedBorder)
                case .shellScript:
                    TextField("Shell command (file path as $1)", text: $config)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("File extensions (comma-separated, or * for any)", text: $fileExtensions)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    let exts = parseExtensions(fileExtensions)
                    let action = CustomDropActionConfig(
                        name: name.trimmingCharacters(in: .whitespaces),
                        actionType: actionType,
                        config: config.trimmingCharacters(in: .whitespaces),
                        fileExtensions: exts
                    )
                    onAdd(action)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !config.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Edit Drop Action Sheet

struct EditDropActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (CustomDropActionConfig) -> Void

    @State private var name: String
    @State private var actionType: CustomDropActionType
    @State private var config: String
    @State private var fileExtensions: String
    private let actionId: UUID

    init(action: CustomDropActionConfig, onSave: @escaping (CustomDropActionConfig) -> Void) {
        self.onSave = onSave
        self.actionId = action.id
        _name = State(initialValue: action.name)
        _actionType = State(initialValue: action.actionType)
        _config = State(initialValue: action.config)
        _fileExtensions = State(initialValue: action.fileExtensions.sorted().joined(separator: ", "))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Drop Action")
                .font(.headline)

            Form {
                TextField("Name", text: $name)

                Picker("Type", selection: $actionType) {
                    ForEach(CustomDropActionType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }

                switch actionType {
                case .shortcut:
                    TextField("Shortcut name", text: $config)
                        .textFieldStyle(.roundedBorder)
                case .shellScript:
                    TextField("Shell command (file path as $1)", text: $config)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("File extensions (comma-separated, or * for any)", text: $fileExtensions)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    let exts = parseExtensions(fileExtensions)
                    let updated = CustomDropActionConfig(
                        id: actionId,
                        name: name.trimmingCharacters(in: .whitespaces),
                        actionType: actionType,
                        config: config.trimmingCharacters(in: .whitespaces),
                        fileExtensions: exts
                    )
                    onSave(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !config.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Edit Pipeline Sheet

struct EditPipelineSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (PipelineConfig) -> Void

    @State private var name: String
    @State private var steps: [PipelineStep]
    @State private var fileExtensions: String
    private let pipelineId: UUID

    init(pipeline: PipelineConfig?, onSave: @escaping (PipelineConfig) -> Void) {
        self.onSave = onSave
        if let pipeline {
            self.pipelineId = pipeline.id
            _name = State(initialValue: pipeline.name)
            _steps = State(initialValue: pipeline.steps)
            _fileExtensions = State(initialValue: pipeline.supportedExtensions.sorted().joined(separator: ", "))
        } else {
            self.pipelineId = UUID()
            _name = State(initialValue: "")
            _steps = State(initialValue: [])
            _fileExtensions = State(initialValue: "*")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(name.isEmpty ? "New Pipeline" : "Edit Pipeline")
                .font(.headline)

            Form {
                TextField("Pipeline name", text: $name)

                TextField("File extensions (comma-separated, or * for any)", text: $fileExtensions)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Section("Steps") {
                    if steps.isEmpty {
                        Text("No steps added yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Picker("", selection: Binding(
                                get: { steps[index].stepType },
                                set: { steps[index].stepType = $0 }
                            )) {
                                ForEach(PipelineStepType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)

                            if step.stepType == .shortcut || step.stepType == .shellScript {
                                TextField(
                                    step.stepType == .shortcut ? "Shortcut name" : "Shell command",
                                    text: Binding(
                                        get: { steps[index].config },
                                        set: { steps[index].config = $0 }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                            } else {
                                Spacer()
                            }

                            Button {
                                moveStepUp(index)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                moveStepDown(index)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == steps.count - 1)

                            Button(role: .destructive) {
                                steps.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Step") {
                        steps.append(PipelineStep(stepType: .compressImage))
                    }
                    .controlSize(.small)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    let exts = parseExtensions(fileExtensions)
                    let pipeline = PipelineConfig(
                        id: pipelineId,
                        name: name.trimmingCharacters(in: .whitespaces),
                        steps: steps,
                        supportedExtensions: exts
                    )
                    onSave(pipeline)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 500, height: 450)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
    }

    private func moveStepUp(_ index: Int) {
        guard index > 0 else { return }
        steps.swapAt(index, index - 1)
    }

    private func moveStepDown(_ index: Int) {
        guard index < steps.count - 1 else { return }
        steps.swapAt(index, index + 1)
    }
}

// MARK: - Shared Helpers

private func parseExtensions(_ input: String) -> Set<String> {
    let trimmed = input.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty || trimmed == "*" {
        return ["*"]
    }
    let exts = trimmed
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: ".", with: "") }
        .filter { !$0.isEmpty }
    return exts.isEmpty ? ["*"] : Set(exts)
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
