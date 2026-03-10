import AppKit

final class NotchPanel: NSPanel {

    /// The state model this panel drives. Set by NotchWindowManager after creation.
    var notchState: NotchState?

    /// Called when the dwell timer fires and expansion should begin. Frame expansion happens before phase change.
    var onExpandRequested: (() -> Void)?

    /// Called when the grace timer fires and collapse should begin. Frame collapse is delayed for animation.
    var onCollapseRequested: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var dwellTimer: DispatchWorkItem?
    private var graceTimer: DispatchWorkItem?

    /// Hover dwell delay in seconds before triggering expansion. Default 200ms.
    var hoverDwellDelay: TimeInterval {
        let ms = UserDefaults.standard.double(forKey: "hoverDwellDelayMs")
        return ms > 0 ? ms / 1000.0 : 0.2
    }

    /// Grace period in seconds before collapsing after mouse exit. Default 300ms.
    private let graceDelay: TimeInterval = 0.3

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

        // Accept mouse events for tracking
        ignoresMouseEvents = false

        // Prevent dragging
        isMovable = false
        isMovableByWindowBackground = false

        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Tracking Area

    /// Install or update tracking area to match the current content view bounds.
    func installTrackingArea() {
        guard let contentView else { return }

        if let existing = trackingArea {
            contentView.removeTrackingArea(existing)
        }

        let area = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Mouse Events

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)

        // Cancel any pending collapse
        graceTimer?.cancel()
        graceTimer = nil

        guard let state = notchState, state.phase == .idle else { return }

        // Start dwell timer — expand frame first, then transition to expanding
        dwellTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let state = self.notchState else { return }
            if state.phase == .idle {
                self.onExpandRequested?()
                state.phase = .expanding
            }
        }
        dwellTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDwellDelay, execute: work)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        // Cancel dwell — mouse left before threshold
        dwellTimer?.cancel()
        dwellTimer = nil

        guard let state = notchState else { return }

        // Only start grace timer if expanded or expanding
        guard state.phase == .expanding || state.phase == .expanded else { return }

        graceTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let state = self.notchState else { return }
            if state.phase == .expanding || state.phase == .expanded {
                state.phase = .idle
                self.onCollapseRequested?()
            }
        }
        graceTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
    }

    /// Cancel all pending timers (called on cleanup).
    func cancelTimers() {
        dwellTimer?.cancel()
        dwellTimer = nil
        graceTimer?.cancel()
        graceTimer = nil
    }
}
