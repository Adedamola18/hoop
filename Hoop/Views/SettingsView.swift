import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

enum SettingsTabKind: String, CaseIterable, Identifiable {
    case general, appearance, hud, widgets, context, dropActions, markets, about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .hud: return "HUD"
        case .widgets: return "Widgets"
        case .context: return "Context"
        case .dropActions: return "Drop Actions"
        case .markets: return "Markets"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .appearance: return "paintbrush"
        case .hud: return "slider.horizontal.3"
        case .widgets: return "square.grid.2x2"
        case .context: return "app.connected.to.app.below.fill"
        case .dropActions: return "arrow.down.doc"
        case .markets: return "chart.line.uptrend.xyaxis"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    let alertEngine: AlertEngine
    let securityGate: SecurityGate
    let widgetRegistry: WidgetRegistry

    @State private var selection: SettingsTabKind = .general

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $selection)
            Divider()
            Group {
                switch selection {
                case .general:
                    GeneralSettingsTab(securityGate: securityGate, widgetRegistry: widgetRegistry)
                case .appearance:
                    AppearanceSettingsTab()
                case .hud:
                    HUDSettingsTab()
                case .widgets:
                    WidgetsSettingsTab()
                case .context:
                    ContextSettingsTab()
                case .dropActions:
                    DropActionsSettingsTab()
                case .markets:
                    MarketsSettingsTab(alertEngine: alertEngine)
                case .about:
                    AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 540)
    }
}

private struct SettingsTabBar: View {
    @Binding var selection: SettingsTabKind

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTabKind.allCases) { tab in
                SettingsTabButton(tab: tab, isSelected: tab == selection) {
                    selection = tab
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTabKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .regular))
                Text(tab.label)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable Settings Components

private struct SettingsPanel<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.06))
        )
    }
}

private struct SettingsIconBadge: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct SettingsListRow<Trailing: View>: View {
    var background: Color = .primary.opacity(0.04)
    @ViewBuilder var content: () -> Trailing

    var body: some View {
        content()
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(background)
            )
    }
}

private struct SheetField<Content: View>: View {
    let label: String
    var hint: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            if let hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SheetFooter<Action: View>: View {
    var cancelLabel: String = "Cancel"
    var onCancel: () -> Void
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(cancelLabel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            action()
        }
        .controlSize(.large)
    }
}

struct AppearanceSettingsTab: View {
    @State private var selectedTheme: ThemeMode = ThemeMode.current

    var body: some View {
        Form {
            Section("Theme") {
                HStack(spacing: 12) {
                    ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                        ThemeCard(mode: mode, isSelected: selectedTheme == mode) {
                            selectedTheme = mode
                            UserDefaults.standard.set(mode.rawValue, forKey: "themeMode")
                            NotificationCenter.default.post(name: .themeModeDidChange, object: nil)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ThemeCard: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                MiniNotchPreview(mode: mode)
                    .padding(.top, 4)

                Spacer(minLength: 0)

                Text(mode.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.primary : .secondary)
                    .lineLimit(1)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(themeBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var themeBackground: some View {
        switch mode {
        case .solidDark:
            RadialGradient(
                colors: [Color(red: 0.059, green: 0.106, blue: 0.180),
                         Color(red: 0.027, green: 0.051, blue: 0.086)],
                center: .center, startRadius: 0, endRadius: 110
            )
        case .translucentDark:
            ZStack {
                Rectangle().fill(.thinMaterial)
                LinearGradient(
                    colors: [Color(red: 0.110, green: 0.137, blue: 0.200).opacity(0.55),
                             Color(red: 0.082, green: 0.106, blue: 0.157).opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        case .liquidGlass:
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                RadialGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)],
                    center: .center, startRadius: 0, endRadius: 90
                )
            }
        }
    }

    private var strokeColor: Color {
        if isSelected { return Color.accentColor }
        switch mode {
        case .solidDark: return Color.white.opacity(0.06)
        case .translucentDark: return Color(red: 0.165, green: 0.204, blue: 0.282)
        case .liquidGlass: return Color.white.opacity(0.18)
        }
    }
}

private struct MiniNotchPreview: View {
    let mode: ThemeMode

    var body: some View {
        UnevenRoundedRectangle(
            cornerRadii: .init(topLeading: 0, bottomLeading: 6, bottomTrailing: 6, topTrailing: 0),
            style: .continuous
        )
        .fill(notchFill)
        .frame(width: 44, height: 12)
    }

    private var notchFill: Color {
        switch mode {
        case .solidDark:
            return Color.black
        case .translucentDark:
            return Color.black.opacity(0.55)
        case .liquidGlass:
            return Color.white.opacity(0.18)
        }
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
                Toggle("Replace system brightness HUD", isOn: $hudReplacementEnabled)
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
    let securityGate: SecurityGate
    let widgetRegistry: WidgetRegistry

    @State private var showSetPIN = false
    @State private var showChangePIN = false
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

            Section("Security") {
                if securityGate.isPINConfigured {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.green)
                        Text("PIN is set")
                        Spacer()
                        Button("Change PIN") { showChangePIN = true }
                    }
                } else {
                    HStack {
                        Image(systemName: "lock.open")
                            .foregroundStyle(.secondary)
                        Text("No PIN configured")
                        Spacer()
                        Button("Set PIN") { showSetPIN = true }
                    }
                }

                if securityGate.isPINConfigured {
                    ForEach(widgetRegistry.widgets, id: \.id) { widget in
                        Toggle(widget.name, isOn: Binding(
                            get: { securityGate.protectedWidgetIds.contains(widget.id) },
                            set: { enabled in
                                var ids = securityGate.protectedWidgetIds
                                if enabled { ids.insert(widget.id) } else { ids.remove(widget.id) }
                                securityGate.protectedWidgetIds = ids
                            }
                        ))
                    }

                    Picker("Auto-lock after", selection: Binding(
                        get: { UserDefaults.standard.object(forKey: "autoLockTimeout") as? Int ?? 5 },
                        set: { UserDefaults.standard.set($0, forKey: "autoLockTimeout") }
                    )) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("Never").tag(0)
                    }

                    Toggle("Lock on display sleep", isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: "lockOnSleep") as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: "lockOnSleep") }
                    ))
                }
            }
            .sheet(isPresented: $showSetPIN) {
                SetPINSheet(securityGate: securityGate)
            }
            .sheet(isPresented: $showChangePIN) {
                ChangePINSheet(securityGate: securityGate)
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
            VStack(alignment: .leading, spacing: 14) {
                customRulesPanel
                widgetSwitchingPanel
                if contextSwitchingEnabled {
                    mediaAppsPanel
                }
                timeProfilesPanel
                focusModePanel
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingAddRule) {
            AddContextRuleSheet { newRule in
                customRules.append(newRule)
                saveCustomRules()
            }
        }
    }

    @ViewBuilder
    private var customRulesPanel: some View {
        SettingsPanel(
            title: "Custom Rules",
            subtitle: "Evaluated top-down. First match overrides everything below."
        ) {
            VStack(spacing: 6) {
                if customRules.isEmpty {
                    emptyMessage("No custom rules yet.")
                } else {
                    ForEach(Array(customRules.enumerated()), id: \.element.id) { index, rule in
                        SettingsListRow {
                            ruleRow(index: index, rule: rule)
                        }
                    }
                }

                Button {
                    showingAddRule = true
                } label: {
                    Label("Add Rule", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func ruleRow(index: Int, rule: ContextRule) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { customRules[index].isEnabled },
                set: { customRules[index].isEnabled = $0; saveCustomRules() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.system(size: 12, weight: .medium))
                Text("When \(rule.condition.conditionType.label.lowercased()) \(rule.condition.displayValue) → \(rule.widgetHint.rawValue)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            Button { moveRuleUp(index) } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)

            Button { moveRuleDown(index) } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == customRules.count - 1)

            Button(role: .destructive) {
                customRules.remove(at: index)
                saveCustomRules()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var widgetSwitchingPanel: some View {
        SettingsPanel(
            title: "Widget Switching",
            subtitle: "Auto-show the right widget based on the frontmost app."
        ) {
            Toggle("Enable context-aware widget switching", isOn: $contextSwitchingEnabled)
                .toggleStyle(.switch)
                .onChange(of: contextSwitchingEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "contextSwitchingEnabled")
                }
        }
    }

    @ViewBuilder
    private var mediaAppsPanel: some View {
        SettingsPanel(
            title: "Media Apps",
            subtitle: "Bundle IDs that show the media widget when frontmost. One per line."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $mediaApps)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(height: 110)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.primary.opacity(0.1))
                    )
                    .onChange(of: mediaApps) { _, newValue in
                        let ids = newValue
                            .split(separator: "\n")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        UserDefaults.standard.set(ids, forKey: "contextMediaAppBundleIDs")
                    }

                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        let defaults = ContextService.defaultMediaAppBundleIDs.sorted()
                        mediaApps = defaults.joined(separator: "\n")
                        UserDefaults.standard.set(defaults, forKey: "contextMediaAppBundleIDs")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var timeProfilesPanel: some View {
        SettingsPanel(
            title: "Time-of-Day Profiles",
            subtitle: "Switch widgets based on the time of day. Focus Mode overrides take priority."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable time-based profiles", isOn: $timeProfilesEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: timeProfilesEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "timeProfilesEnabled")
                    }

                if timeProfilesEnabled {
                    VStack(spacing: 6) {
                        ForEach(ContextService.TimeProfile.allCases) { profile in
                            SettingsListRow {
                                timeProfileRow(profile)
                            }
                        }
                    }
                }
            }
        }
    }

    private func timeProfileRow(_ profile: ContextService.TimeProfile) -> some View {
        HStack(spacing: 10) {
            SettingsIconBadge(icon: profile.defaultIcon, color: .indigo)

            Text(profile.label)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 80, alignment: .leading)

            Spacer(minLength: 8)

            Picker("", selection: Binding(
                get: { timeConfig.startHour(for: profile) },
                set: { timeConfig.setStartHour($0, for: profile); saveTimeConfig() }
            )) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(formatHour(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .frame(width: 92)

            Picker("", selection: Binding(
                get: { timeConfig.widgetHint(for: profile) },
                set: { timeConfig.setWidgetHint($0, for: profile); saveTimeConfig() }
            )) {
                ForEach(ContextService.WidgetHint.allCases, id: \.self) { hint in
                    Text(hint.rawValue.capitalized).tag(hint)
                }
            }
            .labelsHidden()
            .frame(width: 110)
        }
    }

    @ViewBuilder
    private var focusModePanel: some View {
        SettingsPanel(
            title: "Focus Mode",
            subtitle: "Override widgets when a macOS Focus Mode is active."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable Focus Mode overrides", isOn: $focusModeEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: focusModeEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "focusModeEnabled")
                    }

                if focusModeEnabled {
                    if focusConfig.assignments.isEmpty {
                        emptyMessage("No Focus Modes assigned yet.")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(focusConfig.assignments.keys.sorted()), id: \.self) { name in
                                SettingsListRow {
                                    focusRow(name: name)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Focus Mode name (e.g., Work)", text: $newFocusModeName)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let name = newFocusModeName.trimmingCharacters(in: .whitespaces)
                            guard !name.isEmpty else { return }
                            focusConfig.assignments[name] = ContextService.WidgetHint.none
                            saveFocusConfig()
                            newFocusModeName = ""
                        }
                        .controlSize(.regular)
                        .disabled(newFocusModeName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func focusRow(name: String) -> some View {
        HStack(spacing: 10) {
            SettingsIconBadge(icon: "moon.fill", color: .purple)
            Text(name)
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 8)
            Picker("", selection: Binding(
                get: { focusConfig.assignments[name] ?? .none },
                set: { focusConfig.assignments[name] = $0; saveFocusConfig() }
            )) {
                ForEach(ContextService.WidgetHint.allCases, id: \.self) { hint in
                    Text(hint.rawValue.capitalized).tag(hint)
                }
            }
            .labelsHidden()
            .frame(width: 110)

            Button(role: .destructive) {
                focusConfig.assignments.removeValue(forKey: name)
                saveFocusConfig()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 18) {
            SheetHeader(
                title: "Add Context Rule",
                subtitle: "Show a specific widget when this condition is met."
            )

            VStack(alignment: .leading, spacing: 14) {
                SheetField(label: "Rule Name") {
                    TextField("e.g., Coding hours", text: $ruleName)
                        .textFieldStyle(.roundedBorder)
                }

                SheetField(label: "When") {
                    Picker("", selection: $conditionType) {
                        ForEach(ContextRule.ConditionType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                switch conditionType {
                case .app:
                    SheetField(
                        label: "App Bundle ID",
                        hint: "Find with: osascript -e 'id of app \"AppName\"'"
                    ) {
                        TextField("com.apple.Xcode", text: $appBundleID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                case .time:
                    SheetField(label: "Time Profile") {
                        Picker("", selection: $timeProfile) {
                            ForEach(ContextService.TimeProfile.allCases) { profile in
                                Text(profile.label).tag(profile)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                case .focus:
                    SheetField(label: "Focus Mode Name") {
                        TextField("Work", text: $focusModeName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                SheetField(label: "Show Widget") {
                    Picker("", selection: $widgetHint) {
                        ForEach(ContextService.WidgetHint.allCases, id: \.self) { hint in
                            Text(hint.rawValue.capitalized).tag(hint)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            SheetFooter(onCancel: { dismiss() }) {
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
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
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
            VStack(alignment: .leading, spacing: 14) {
                builtInPanel
                customActionsPanel
                pipelinesPanel
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    @ViewBuilder
    private var builtInPanel: some View {
        SettingsPanel(
            title: "Built-in Actions",
            subtitle: "Always available. Drop a supported file on the notch to use."
        ) {
            VStack(spacing: 8) {
                SettingsListRow {
                    actionRowContent(
                        icon: "arrow.down.right.and.arrow.up.left",
                        color: .blue,
                        title: "Compress Image",
                        subtitle: "png · jpg · jpeg · tiff · bmp · heic · webp",
                        trailing: { EmptyView() }
                    )
                }
                SettingsListRow {
                    actionRowContent(
                        icon: "doc.text.viewfinder",
                        color: .purple,
                        title: "Extract Text (OCR)",
                        subtitle: "png · jpg · jpeg · tiff · bmp · heic · webp · pdf",
                        trailing: { EmptyView() }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var customActionsPanel: some View {
        SettingsPanel(
            title: "Custom Actions",
            subtitle: "Run a Shortcut or shell command when a matching file is dropped."
        ) {
            VStack(spacing: 6) {
                if customActions.isEmpty {
                    emptyMessage("No custom actions yet.")
                } else {
                    ForEach(Array(customActions.enumerated()), id: \.element.id) { index, action in
                        SettingsListRow {
                            actionRowContent(
                                icon: action.actionType.iconName,
                                color: .green,
                                title: action.name,
                                subtitle: "\(action.actionType.label) · \(extensionsLabel(action.fileExtensions))"
                            ) {
                                rowActions(
                                    edit: { editingAction = customActions[index] },
                                    delete: {
                                        customActions.remove(at: index)
                                        CustomDropActionStore.save(customActions)
                                    }
                                )
                            }
                        }
                    }
                }

                Button {
                    showingAddAction = true
                } label: {
                    Label("Add Action", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var pipelinesPanel: some View {
        SettingsPanel(
            title: "Pipelines",
            subtitle: "Chain actions sequentially. Each step's output feeds the next."
        ) {
            VStack(spacing: 6) {
                if pipelines.isEmpty {
                    emptyMessage("No pipelines yet.")
                } else {
                    ForEach(Array(pipelines.enumerated()), id: \.element.id) { index, pipeline in
                        SettingsListRow {
                            actionRowContent(
                                icon: "arrow.triangle.branch",
                                color: .orange,
                                title: pipeline.name,
                                subtitle: "\(pipeline.steps.count) step\(pipeline.steps.count == 1 ? "" : "s") · \(extensionsLabel(pipeline.supportedExtensions))"
                            ) {
                                rowActions(
                                    edit: { editingPipeline = pipelines[index] },
                                    delete: {
                                        pipelines.remove(at: index)
                                        PipelineStore.save(pipelines)
                                    }
                                )
                            }
                        }
                    }
                }

                Button {
                    showingAddPipeline = true
                } label: {
                    Label("Add Pipeline", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func actionRowContent<Trailing: View>(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            SettingsIconBadge(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    @ViewBuilder
    private func rowActions(edit: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        Button(action: edit) {
            Image(systemName: "pencil")
        }
        .buttonStyle(.borderless)

        Button(role: .destructive, action: delete) {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
    }

    private func emptyMessage(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 18) {
            SheetHeader(
                title: "Add Drop Action",
                subtitle: "Run a Shortcut or shell command when a matching file is dropped."
            )

            VStack(alignment: .leading, spacing: 14) {
                SheetField(label: "Name") {
                    TextField("My Action", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                SheetField(label: "Type") {
                    Picker("", selection: $actionType) {
                        ForEach(CustomDropActionType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                switch actionType {
                case .shortcut:
                    SheetField(label: "Shortcut Name") {
                        TextField("Name of a Shortcut from the Shortcuts app", text: $config)
                            .textFieldStyle(.roundedBorder)
                    }
                case .shellScript:
                    SheetField(
                        label: "Shell Command",
                        hint: "Use $1 for the dropped file path. Runs in /bin/zsh."
                    ) {
                        TextField("/usr/bin/file \"$1\"", text: $config)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                SheetField(
                    label: "File Extensions",
                    hint: "Comma-separated, or * for any file type."
                ) {
                    TextField("*", text: $fileExtensions)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }

            SheetFooter(onCancel: { dismiss() }) {
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
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 440)
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
        VStack(alignment: .leading, spacing: 18) {
            SheetHeader(
                title: "Edit Drop Action",
                subtitle: "Update this action's name, command, or supported file types."
            )

            VStack(alignment: .leading, spacing: 14) {
                SheetField(label: "Name") {
                    TextField("My Action", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                SheetField(label: "Type") {
                    Picker("", selection: $actionType) {
                        ForEach(CustomDropActionType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                switch actionType {
                case .shortcut:
                    SheetField(label: "Shortcut Name") {
                        TextField("Name of a Shortcut from the Shortcuts app", text: $config)
                            .textFieldStyle(.roundedBorder)
                    }
                case .shellScript:
                    SheetField(
                        label: "Shell Command",
                        hint: "Use $1 for the dropped file path. Runs in /bin/zsh."
                    ) {
                        TextField("/usr/bin/file \"$1\"", text: $config)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                SheetField(
                    label: "File Extensions",
                    hint: "Comma-separated, or * for any file type."
                ) {
                    TextField("*", text: $fileExtensions)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }

            SheetFooter(onCancel: { dismiss() }) {
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
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 440)
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
        VStack(alignment: .leading, spacing: 18) {
            SheetHeader(
                title: name.isEmpty ? "New Pipeline" : "Edit Pipeline",
                subtitle: "Chain actions sequentially. Each step's output feeds the next."
            )

            VStack(alignment: .leading, spacing: 14) {
                SheetField(label: "Pipeline Name") {
                    TextField("My Pipeline", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                SheetField(
                    label: "File Extensions",
                    hint: "Comma-separated, or * for any file type."
                ) {
                    TextField("*", text: $fileExtensions)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                stepsSection
            }

            SheetFooter(onCancel: { dismiss() }) {
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
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 520, height: 480)
    }

    @ViewBuilder
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if steps.isEmpty {
                HStack {
                    Text("No steps added yet.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.primary.opacity(0.04))
                )
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            stepRow(index: index, step: step)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Button {
                steps.append(PipelineStep(stepType: .compressImage))
            } label: {
                Label("Add Step", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
        }
    }

    private func stepRow(index: Int, step: PipelineStep) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)

            Picker("", selection: Binding(
                get: { steps[index].stepType },
                set: { steps[index].stepType = $0 }
            )) {
                ForEach(PipelineStepType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .labelsHidden()
            .frame(width: 130)

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

            Button { moveStepUp(index) } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)

            Button { moveStepDown(index) } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == steps.count - 1)

            Button(role: .destructive) {
                steps.remove(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.04))
        )
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

// MARK: - About Settings Tab

struct AboutSettingsTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // Hoop logo
            HoopLogo()
                .frame(width: 80, height: 80)

            Spacer().frame(height: 16)

            // App name & version
            Text("Hoop")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("v\(appVersion)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            Spacer().frame(height: 24)

            // Author
            VStack(spacing: 4) {
                Text("Hoop is made by")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                Text("Damola Olutoke")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer().frame(height: 20)

            // Description
            Text("A utility that lives in your MacBook notch.\nMedia \u{00B7} HUD \u{00B7} Widgets \u{00B7} Markets")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()

            // Footer
            Text("\u{00A9} 2026 Damola Olutoke")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PIN Sheets

private struct SecurityLogo: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HoopLogo()
                .frame(width: 64, height: 64)

            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(Color.accentColor.gradient)
                )
                .overlay(
                    Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                )
                .offset(x: 4, y: -4)
        }
    }
}

private struct SetPINSheet: View {
    @Environment(\.dismiss) private var dismiss
    let securityGate: SecurityGate
    @State private var pin: String = ""

    private var isValid: Bool { pin.count >= 4 && pin.count <= 6 }

    var body: some View {
        VStack(spacing: 16) {
            SecurityLogo()
                .padding(.top, 4)

            Text("Set PIN")
                .font(.system(size: 16, weight: .semibold))

            SecureField("Enter 4-6 digit PIN", text: $pin)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Cancel") {
                    pin = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .frame(maxWidth: .infinity)

                Button("Set") {
                    guard isValid else { return }
                    _ = securityGate.setupPIN(pin)
                    pin = ""
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 320)
    }
}

private struct ChangePINSheet: View {
    @Environment(\.dismiss) private var dismiss
    let securityGate: SecurityGate
    @State private var current: String = ""
    @State private var newPIN: String = ""

    private var isValid: Bool {
        !current.isEmpty && newPIN.count >= 4 && newPIN.count <= 6
    }

    var body: some View {
        VStack(spacing: 16) {
            SecurityLogo()
                .padding(.top, 4)

            Text("Change PIN")
                .font(.system(size: 16, weight: .semibold))

            VStack(spacing: 10) {
                SecureField("Current PIN", text: $current)
                    .textFieldStyle(.roundedBorder)
                SecureField("New PIN (4-6 digits)", text: $newPIN)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    current = ""; newPIN = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .frame(maxWidth: .infinity)

                Button("Change") {
                    guard isValid else { return }
                    _ = securityGate.changePIN(currentPIN: current, newPIN: newPIN)
                    current = ""; newPIN = ""
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(width: 340)
    }
}

/// A custom drawn hoop logo — a stylized ring with gradient.
private struct HoopLogo: View {
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .cyan, .blue, .purple],
                        center: .center
                    ),
                    lineWidth: 6
                )
                .blur(radius: 6)
                .opacity(0.5)

            // Main ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.6, green: 0.3, blue: 1.0),
                            Color(red: 0.3, green: 0.5, blue: 1.0),
                            Color(red: 0.2, green: 0.8, blue: 0.9),
                            Color(red: 0.3, green: 0.5, blue: 1.0),
                            Color(red: 0.6, green: 0.3, blue: 1.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 5
                )

            // Inner highlight
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 1)
                .padding(2)

            // Center notch shape hint
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.6),
                            Color(red: 0.3, green: 0.4, blue: 0.8).opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 24, height: 12)
                .offset(y: -2)
        }
        .padding(8)
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

// MARK: - Markets Settings Tab

struct MarketsSettingsTab: View {
    let alertEngine: AlertEngine

    var body: some View {
        Form {
            Section("Platforms") {
                ForEach(["binance", "bybit", "polymarket", "kalshi"], id: \.self) { platformId in
                    PlatformConfigRow(alertEngine: alertEngine, platformId: platformId)
                }
            }

            Section("Webhook (TradingView)") {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("9876", value: .init(
                        get: { Int(UserDefaults.standard.object(forKey: "webhookPort") as? Int ?? 9876) },
                        set: { UserDefaults.standard.set($0, forKey: "webhookPort") }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Bearer Token (optional)")
                    Spacer()
                    TextField("", text: .init(
                        get: { UserDefaults.standard.string(forKey: "webhookBearerToken") ?? "" },
                        set: { UserDefaults.standard.set($0, forKey: "webhookBearerToken") }
                    ))
                    .frame(width: 200)
                    .textFieldStyle(.roundedBorder)
                }

                Toggle("Enable Webhook Server", isOn: .init(
                    get: { UserDefaults.standard.bool(forKey: "webhookEnabled") },
                    set: { UserDefaults.standard.set($0, forKey: "webhookEnabled") }
                ))

                Button("Send Test Alert") {
                    alertEngine.webhookServer?.sendTestAlert()
                }
            }

            Section("Alert Behavior") {
                HStack {
                    Text("Dedup Window")
                    Spacer()
                    Text("\(Int(UserDefaults.standard.object(forKey: "alertDedupWindow") as? Double ?? 60))s")
                    Slider(value: .init(
                        get: { UserDefaults.standard.object(forKey: "alertDedupWindow") as? Double ?? 60 },
                        set: { UserDefaults.standard.set($0, forKey: "alertDedupWindow") }
                    ), in: 30...300, step: 30)
                    .frame(width: 150)
                }

                HStack {
                    Text("Toast Duration")
                    Spacer()
                    Text("\(Int(UserDefaults.standard.object(forKey: "alertDismissTimeout") as? Double ?? 4))s")
                    Slider(value: .init(
                        get: { UserDefaults.standard.object(forKey: "alertDismissTimeout") as? Double ?? 4 },
                        set: { UserDefaults.standard.set($0, forKey: "alertDismissTimeout") }
                    ), in: 2...10, step: 1)
                    .frame(width: 150)
                }

                HStack {
                    Text("Snooze Duration")
                    Spacer()
                    Text("\(Int((UserDefaults.standard.object(forKey: "alertSnoozeDuration") as? Double ?? 300) / 60))m")
                    Slider(value: .init(
                        get: { UserDefaults.standard.object(forKey: "alertSnoozeDuration") as? Double ?? 300 },
                        set: { UserDefaults.standard.set($0, forKey: "alertSnoozeDuration") }
                    ), in: 60...1800, step: 60)
                    .frame(width: 150)
                }

                Toggle("System notifications for high-priority alerts", isOn: .init(
                    get: { UserDefaults.standard.bool(forKey: "alertSystemNotifications") },
                    set: { UserDefaults.standard.set($0, forKey: "alertSystemNotifications") }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
    }
}

struct PlatformConfigRow: View {
    let alertEngine: AlertEngine
    let platformId: String

    @State private var config: PlatformConfig

    init(alertEngine: AlertEngine, platformId: String) {
        self.alertEngine = alertEngine
        self.platformId = platformId
        self._config = State(initialValue: alertEngine.config(for: platformId))
    }

    private var platformName: String {
        platformId.capitalized
    }

    var body: some View {
        DisclosureGroup {
            if platformId == "binance" || platformId == "bybit" {
                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("", text: Binding(
                        get: { config.apiKey ?? "" },
                        set: { config.apiKey = $0.isEmpty ? nil : $0; save() }
                    ))
                    .frame(width: 200)
                    .textFieldStyle(.roundedBorder)
                }
            }

            if platformId == "polymarket" || platformId == "kalshi" {
                HStack {
                    Text("Poll Interval")
                    Spacer()
                    Text("\(Int(config.pollIntervalSeconds))s")
                    Slider(value: $config.pollIntervalSeconds, in: 5...300, step: 5)
                        .frame(width: 150)
                        .onChange(of: config.pollIntervalSeconds) { _, _ in save() }
                }
            }

            HStack {
                Text("Active Hours")
                Spacer()
                Picker("From", selection: $config.activeHoursStart) {
                    ForEach(0..<24, id: \.self) { Text("\($0):00") }
                }.frame(width: 80).onChange(of: config.activeHoursStart) { _, _ in save() }
                Text("to")
                Picker("To", selection: $config.activeHoursEnd) {
                    ForEach(0..<25, id: \.self) { Text($0 == 24 ? "24:00" : "\($0):00") }
                }.frame(width: 80).onChange(of: config.activeHoursEnd) { _, _ in save() }
            }

            HStack {
                Text("High Alert Threshold")
                Spacer()
                Text("\(String(format: "%.0f", config.thresholdHigh))%")
                Slider(value: $config.thresholdHigh, in: 1...20, step: 1)
                    .frame(width: 150)
                    .onChange(of: config.thresholdHigh) { _, _ in save() }
            }
        } label: {
            HStack {
                Toggle(platformName, isOn: $config.isEnabled)
                    .onChange(of: config.isEnabled) { _, _ in save() }
            }
        }
    }

    private func save() {
        alertEngine.updateConfig(for: platformId, config)
    }
}
