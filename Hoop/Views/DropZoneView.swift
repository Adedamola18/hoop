import SwiftUI

struct DropZoneView: View {
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(pulseScale)

            Text("Drop to process")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    .white.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .padding(8)
                .opacity(pulseScale > 1.02 ? 0.6 : 1.0)
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.08
            }
        }
        .onDisappear {
            pulseScale = 1.0
        }
    }
}
