import AppKit
import SwiftUI

final class NotchWindowManager {

    private var windows: [String: (panel: NotchPanel, state: NotchState)] = [:]
    private var pendingSynchronize: DispatchWorkItem?

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
        let state = NotchState()
        state.screenHasNotch = screen.hasNotch

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

        windows[screen.stableIdentifier] = (panel: panel, state: state)
    }

    private func repositionWindow(_ id: String, on screen: NSScreen) {
        guard let entry = windows[id] else { return }
        entry.state.screenHasNotch = screen.hasNotch
        entry.panel.setFrame(screen.overlayFrame, display: true)
        entry.panel.installTrackingArea()
    }
}
