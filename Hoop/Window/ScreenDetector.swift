import AppKit

extension NSScreen {

    /// Returns `true` if the screen has a hardware notch.
    /// Detection relies on the presence of both auxiliary top areas,
    /// which only exist on notch-equipped displays.
    var hasNotch: Bool {
        auxiliaryTopLeftArea != nil && auxiliaryTopRightArea != nil
    }

    /// The size of the hardware notch, computed from the auxiliary top areas.
    /// Width = screen width minus the two auxiliary area widths.
    /// Height = the safe area inset at the top (notch height).
    var notchSize: NSSize? {
        guard let leftWidth = auxiliaryTopLeftArea?.width,
              let rightWidth = auxiliaryTopRightArea?.width else { return nil }
        return NSSize(
            width: frame.width - leftWidth - rightWidth,
            height: safeAreaInsets.top
        )
    }

    /// The frame of the hardware notch in screen coordinates.
    /// Centered horizontally, flush with the top of the screen.
    var notchFrame: NSRect? {
        guard let size = notchSize else { return nil }
        return NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Fallback frame for non-notch screens: a virtual pill at top-center.
    /// Width is fixed at 180pt; height matches the menu bar height (minimum 32pt).
    var virtualPillFrame: NSRect {
        let width: CGFloat = 180
        let menuBarHeight = frame.maxY - visibleFrame.maxY
        let height = max(menuBarHeight, 32)
        return NSRect(
            x: frame.midX - width / 2,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Convenience: returns the notch frame if available, otherwise the virtual pill frame.
    var overlayFrame: NSRect {
        notchFrame ?? virtualPillFrame
    }

    /// Frame for the expanded overlay, centered at the top of the screen.
    func expandedOverlayFrame(expandedWidth: CGFloat = 600) -> NSRect {
        let expandedHeight: CGFloat = NotchState.expandedHeight
        return NSRect(
            x: frame.midX - expandedWidth / 2,
            y: frame.maxY - expandedHeight,
            width: expandedWidth,
            height: expandedHeight
        )
    }

    /// A stable identifier for this screen that persists across reconnections.
    /// Uses the CGDirectDisplayID from the device description dictionary.
    var stableIdentifier: String {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return "unknown-\(hash)"
        }
        return String(screenNumber)
    }
}
