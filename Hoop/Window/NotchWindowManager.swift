import AppKit
import SwiftUI

final class NotchWindowManager {

    private var windows: [String: (panel: NotchPanel, state: NotchState)] = [:]
    private var pendingSynchronize: DispatchWorkItem?
    private var collapseWorkItems: [String: DispatchWorkItem] = [:]
    private var expandedTransitionItems: [String: DispatchWorkItem] = [:]
    private var globalClickMonitor: Any?
    private var globalHotkeyMonitor: Any?
    let mediaService = MediaService()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activationTriggerDidChange(_:)),
            name: .activationTriggerDidChange,
            object: nil
        )
        synchronizeWindows()
        updateHotkeyMonitor()
        mediaService.startObserving()
    }

    deinit {
        mediaService.stopObserving()
        NotificationCenter.default.removeObserver(self)
        pendingSynchronize?.cancel()
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        removeHotkeyMonitor()
        for (_, entry) in windows {
            entry.panel.cancelTimers()
        }
        for (_, item) in collapseWorkItems { item.cancel() }
        for (_, item) in expandedTransitionItems { item.cancel() }
    }

    // MARK: - Screen Change Handling

    @objc private func screenConfigurationDidChange(_ notification: Notification) {
        scheduleSynchronize()
    }

    @objc private func activationTriggerDidChange(_ notification: Notification) {
        updateHotkeyMonitor()

        // Collapse any expanded panels when trigger changes
        for (id, entry) in windows {
            if entry.state.phase == .expanding || entry.state.phase == .expanded {
                entry.panel.cancelTimers()
                entry.state.phase = .idle
                immediateCollapse(id: id)
            }
        }
    }

    /// Debounce rapid screen changes (e.g., connecting/disconnecting monitors)
    /// by coalescing into a single synchronize call after 500ms.
    private func scheduleSynchronize() {
        pendingSynchronize?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.synchronizeWindows()
        }
        pendingSynchronize = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    // MARK: - Window Lifecycle

    private func synchronizeWindows() {
        let currentIdentifiers = Set(NSScreen.screens.map(\.stableIdentifier))

        // Remove windows for disconnected screens
        let staleIdentifiers = Set(windows.keys).subtracting(currentIdentifiers)
        for id in staleIdentifiers {
            windows[id]?.panel.cancelTimers()
            windows[id]?.panel.orderOut(nil)
            windows.removeValue(forKey: id)
            collapseWorkItems[id]?.cancel()
            collapseWorkItems.removeValue(forKey: id)
            expandedTransitionItems[id]?.cancel()
            expandedTransitionItems.removeValue(forKey: id)
        }

        // Create or reposition windows for current screens
        for screen in NSScreen.screens {
            let id = screen.stableIdentifier
            if windows[id] == nil {
                createWindow(for: screen)
            } else {
                repositionWindow(id, on: screen)
            }
        }
    }

    private func createWindow(for screen: NSScreen) {
        let id = screen.stableIdentifier
        let state = NotchState()
        state.screenHasNotch = screen.hasNotch
        state.collapsedSize = screen.overlayFrame.size

        let rootView = NotchRootView(state: state, mediaService: mediaService)
        let hostingView = NSHostingView(rootView: rootView)

        let panel = NotchPanel(
            contentRect: screen.overlayFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.notchState = state
        panel.setFrame(screen.overlayFrame, display: true)
        panel.installTrackingArea()
        panel.orderFront(nil)

        // Wire up expand/collapse/dismiss callbacks
        panel.onExpandRequested = { [weak self] in
            self?.expandPanel(id: id)
        }
        panel.onCollapseRequested = { [weak self] in
            self?.scheduleCollapsePanel(id: id)
        }
        panel.onDismissRequested = { [weak self] in
            self?.immediateCollapse(id: id)
        }
        panel.onSwipeSkip = { [weak self] isNext in
            if isNext {
                self?.mediaService.nextTrack()
            } else {
                self?.mediaService.previousTrack()
            }
        }

        windows[id] = (panel: panel, state: state)
    }

    private func repositionWindow(_ id: String, on screen: NSScreen) {
        guard let entry = windows[id] else { return }
        entry.state.screenHasNotch = screen.hasNotch
        entry.state.collapsedSize = screen.overlayFrame.size

        // Only reposition if not currently expanded
        if entry.state.phase == .idle {
            entry.panel.setFrame(screen.overlayFrame, display: true)
            entry.panel.installTrackingArea()
        }
    }

    // MARK: - Expand / Collapse

    private func expandPanel(id: String) {
        guard let entry = windows[id] else { return }
        let screen = NSScreen.screens.first { $0.stableIdentifier == id }
        guard let screen else { return }

        // Cancel any pending collapse
        collapseWorkItems[id]?.cancel()
        collapseWorkItems.removeValue(forKey: id)

        // Snap panel frame to expanded size (SwiftUI spring animates the visual content)
        let expandedFrame = screen.expandedOverlayFrame(expandedWidth: entry.state.expandedWidth)
        entry.panel.setFrame(expandedFrame, display: true)
        entry.panel.installTrackingArea()

        // Make panel key to receive Escape key events
        entry.panel.makeKey()

        // Monitor clicks outside to dismiss
        installGlobalClickMonitor()

        // Transition expanding -> expanded after spring animation settles
        expandedTransitionItems[id]?.cancel()
        let work = DispatchWorkItem {
            if entry.state.phase == .expanding {
                entry.state.phase = .expanded
            }
        }
        expandedTransitionItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func scheduleCollapsePanel(id: String) {
        // Cancel any pending expand transition
        expandedTransitionItems[id]?.cancel()
        expandedTransitionItems.removeValue(forKey: id)

        // Delay frame collapse to let SwiftUI spring animation complete
        collapseWorkItems[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.collapsePanel(id: id)
        }
        collapseWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func collapsePanel(id: String) {
        guard let entry = windows[id], entry.state.phase == .idle else { return }
        let screen = NSScreen.screens.first { $0.stableIdentifier == id }
        guard let screen else { return }

        entry.panel.setFrame(screen.overlayFrame, display: true)
        entry.panel.installTrackingArea()
        removeGlobalClickMonitor()
    }

    /// Immediate collapse triggered by Escape key or click outside — no grace timer.
    private func immediateCollapse(id: String) {
        // Cancel any pending work
        expandedTransitionItems[id]?.cancel()
        expandedTransitionItems.removeValue(forKey: id)
        collapseWorkItems[id]?.cancel()
        collapseWorkItems.removeValue(forKey: id)

        // Delay frame shrink for SwiftUI animation
        let work = DispatchWorkItem { [weak self] in
            guard let entry = self?.windows[id] else { return }
            let screen = NSScreen.screens.first { $0.stableIdentifier == id }
            guard let screen else { return }
            entry.panel.setFrame(screen.overlayFrame, display: true)
            entry.panel.installTrackingArea()
            self?.removeGlobalClickMonitor()
        }
        collapseWorkItems[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Global Click Monitor

    private func installGlobalClickMonitor() {
        guard globalClickMonitor == nil else { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleGlobalClick(event)
        }
    }

    private func removeGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    private func handleGlobalClick(_ event: NSEvent) {
        // Dismiss any expanded panels when clicking outside
        for (id, entry) in windows {
            guard entry.state.phase == .expanding || entry.state.phase == .expanded else { continue }

            let clickLocation = NSEvent.mouseLocation
            let panelFrame = entry.panel.frame

            if !panelFrame.contains(clickLocation) {
                entry.panel.cancelTimers()
                entry.state.phase = .idle
                immediateCollapse(id: id)
            }
        }
    }

    // MARK: - Global Hotkey Monitor

    private func updateHotkeyMonitor() {
        removeHotkeyMonitor()

        guard ActivationTrigger.current == .hotkey else { return }

        let targetKeyCode = UInt16({
            let v = UserDefaults.standard.object(forKey: "hotkeyKeyCode")
            return (v as? Int) ?? 0x2D // kVK_ANSI_N
        }())
        let targetModifiers: NSEvent.ModifierFlags = {
            let v = UserDefaults.standard.object(forKey: "hotkeyModifierFlags")
            let raw = (v as? Int) ?? Int(NSEvent.ModifierFlags.option.rawValue)
            return NSEvent.ModifierFlags(rawValue: UInt(raw))
        }()
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventFlags = event.modifierFlags.intersection(relevantFlags)
            let wantedFlags = targetModifiers.intersection(relevantFlags)
            guard event.keyCode == targetKeyCode, eventFlags == wantedFlags else { return }
            self?.toggleHotkeyActivation()
        }
    }

    private func removeHotkeyMonitor() {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
    }

    private func toggleHotkeyActivation() {
        // Find primary screen panel (first with notch, or first available)
        guard let (id, entry) = windows.first(where: { $0.value.state.screenHasNotch }) ?? windows.first else { return }

        if entry.state.phase == .idle {
            expandPanel(id: id)
            entry.state.phase = .expanding
        } else if entry.state.phase == .expanding || entry.state.phase == .expanded {
            entry.panel.cancelTimers()
            entry.state.phase = .idle
            immediateCollapse(id: id)
        }
    }
}
