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

        let target = NSScreen.screens.first(where: { $0.hasNotch }) ?? NSScreen.main
        let size = NSSize(width: 550, height: 440)
        if let screen = target {
            let x = screen.frame.midX - size.width / 2
            let y = screen.frame.midY - size.height / 2
            window.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
        } else {
            window.setContentSize(size)
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
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 440),
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
