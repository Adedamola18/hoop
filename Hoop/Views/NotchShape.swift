import SwiftUI

/// A shape that draws a rounded rectangle with an optional concave cutout at the
/// top center, matching the hardware notch profile on MacBook Pro displays.
/// On non-notch Macs the shape is a simple rounded rectangle (capsule-like).
struct NotchShape: Shape {
    var cornerRadius: CGFloat
    /// Width of the hardware notch cutout.
    var notchWidth: CGFloat
    /// Depth of the notch cutout (0 = no cutout, animates to full depth when expanded).
    var notchDepth: CGFloat
    /// Whether the display has a hardware notch.
    var hasNotch: Bool

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(cornerRadius, AnimatablePair(notchWidth, notchDepth)) }
        set {
            cornerRadius = newValue.first
            notchWidth = newValue.second.first
            notchDepth = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let cr = min(cornerRadius, rect.width / 2, rect.height / 2)

        // No notch or cutout too small — draw simple rounded rect
        guard hasNotch, notchDepth > 1, notchWidth > 0,
              notchWidth < rect.width - 2 * cr else {
            return RoundedRectangle(cornerRadius: cr).path(in: rect)
        }

        var path = Path()
        let curveSize = min(8, notchDepth / 2, (rect.width - notchWidth) / 4)

        let notchLeft = rect.midX - notchWidth / 2
        let notchRight = rect.midX + notchWidth / 2
        let notchBottom = rect.minY + notchDepth

        // Start at bottom-left (after corner)
        path.move(to: CGPoint(x: rect.minX + cr, y: rect.maxY))

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.maxY))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cr, y: rect.maxY - cr),
            radius: cr, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cr))

        // Top-right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cr, y: rect.minY + cr),
            radius: cr, startAngle: .degrees(0), endAngle: .degrees(-90), clockwise: true
        )

        // Top edge → right side of notch cutout
        path.addLine(to: CGPoint(x: notchRight + curveSize, y: rect.minY))

        // Concave curve into notch (right side) — smooth transition from top edge down
        path.addQuadCurve(
            to: CGPoint(x: notchRight, y: rect.minY + curveSize),
            control: CGPoint(x: notchRight, y: rect.minY)
        )

        // Right wall of notch
        path.addLine(to: CGPoint(x: notchRight, y: notchBottom - curveSize))

        // Bottom-right of notch cutout
        path.addQuadCurve(
            to: CGPoint(x: notchRight - curveSize, y: notchBottom),
            control: CGPoint(x: notchRight, y: notchBottom)
        )

        // Bottom of notch cutout
        path.addLine(to: CGPoint(x: notchLeft + curveSize, y: notchBottom))

        // Bottom-left of notch cutout
        path.addQuadCurve(
            to: CGPoint(x: notchLeft, y: notchBottom - curveSize),
            control: CGPoint(x: notchLeft, y: notchBottom)
        )

        // Left wall of notch
        path.addLine(to: CGPoint(x: notchLeft, y: rect.minY + curveSize))

        // Concave curve out of notch (left side) — smooth transition back to top edge
        path.addQuadCurve(
            to: CGPoint(x: notchLeft - curveSize, y: rect.minY),
            control: CGPoint(x: notchLeft, y: rect.minY)
        )

        // Top edge → top-left corner
        path.addLine(to: CGPoint(x: rect.minX + cr, y: rect.minY))

        // Top-left corner
        path.addArc(
            center: CGPoint(x: rect.minX + cr, y: rect.minY + cr),
            radius: cr, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: true
        )

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cr))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: rect.minX + cr, y: rect.maxY - cr),
            radius: cr, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true
        )

        path.closeSubpath()
        return path
    }
}
