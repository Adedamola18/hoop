import AppKit
import SwiftUI

final class ClipboardFullWindow {
    private let clipboardService: ClipboardService
    private var window: NSPanel?

    init(clipboardService: ClipboardService) {
        self.clipboardService = clipboardService
    }

    func toggle() {
        if window?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if window == nil {
            buildWindow()
        }
        guard let window else { return }

        // Center on the screen with the notch (or main screen as fallback)
        let target = NSScreen.screens.first(where: { $0.hasNotch }) ?? NSScreen.main
        if let screen = target {
            let frame = window.frame
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.midY - frame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.orderOut(nil)
    }

    private func buildWindow() {
        let view = ClipboardFullView(
            clipboardService: clipboardService,
            onClose: { [weak self] in self?.close() }
        )
        let host = NSHostingController(rootView: view)
        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.title = "Clipboard"
        win.contentViewController = host
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.minSize = NSSize(width: 600, height: 460)
        window = win
    }
}
