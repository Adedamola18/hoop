import SwiftUI

struct HUDOverlayView: View {
    let hudService: HUDService

    @State private var dragLevel: Float?

    private var level: Float {
        dragLevel ?? hudService.currentLevel
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))

                    Capsule()
                        .fill(.white)
                        .frame(width: max(4, geo.size.width * CGFloat(level)))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = Float(value.location.x / geo.size.width)
                            let clamped = max(0, min(1, ratio))
                            dragLevel = clamped
                            hudService.currentLevel = clamped
                            hudService.setBrightness(clamped)
                        }
                        .onEnded { _ in
                            dragLevel = nil
                        }
                )
            }
            .frame(height: 6)

            Text("\(Int(level * 100))%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
