import AppKit

final class NotchPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing bufferingType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: bufferingType,
            defer: flag
        )

        // Visual properties
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false

        // Positioning: above menu bar, below system alerts
        level = .statusBar + 1
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary
        ]

        // Agent app: overlay must not disappear when app loses focus
        hidesOnDeactivate = false

        // Start ignoring mouse events; toggled dynamically in Phase 2
        ignoresMouseEvents = true

        // Prevent dragging
        isMovable = false
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
