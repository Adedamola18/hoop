import SwiftUI

struct HUDOverlayView: View {
    let hudService: HUDService

    @State private var dragLevel: Float?

    private var level: Float {
        dragLevel ?? hudService.currentLevel
    }

    var body: some View {
        HStack(spacing: 12) {
            hudIcon
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(.white.opacity(0.2))

                    // Filled portion
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
                            if hudService.hudType == .volume {
                                hudService.setVolume(clamped)
                            }
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

    @ViewBuilder
    private var hudIcon: some View {
        switch hudService.hudType {
        case .volume:
            Image(systemName: volumeIconName)
        case .brightness:
            Image(systemName: "sun.max.fill")
        }
    }

    private var volumeIconName: String {
        if level <= 0 {
            return "speaker.slash.fill"
        } else if level < 0.33 {
            return "speaker.wave.1.fill"
        } else if level < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}
