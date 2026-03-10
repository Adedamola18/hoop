import AppKit
import SwiftUI

final class NotchWindowManager {

    private var windows: [String: (panel: NotchPanel, state: NotchState)] = [:]
    private var pendingSynchronize: DispatchWorkItem?
    private var collapseWorkItems: [String: DispatchWorkItem] = [:]
    private var expandedTransitionItems: [String: DispatchWorkItem] = [:]

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        synchronizeWindows()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pendingSynchronize?.cancel()
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

        let rootView = NotchRootView(state: state)
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

        // Wire up expand/collapse callbacks
        panel.onExpandRequested = { [weak self] in
            self?.expandPanel(id: id)
        }
        panel.onCollapseRequested = { [weak self] in
            self?.scheduleCollapsePanel(id: id)
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
    }
}
