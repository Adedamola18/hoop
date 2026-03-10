import SwiftUI

struct PrivacyIndicatorView: View {
    let privacyService: PrivacyService

    var body: some View {
        HStack(spacing: 4) {
            if privacyService.isScreenRecording {
                RecordingDot()
            }
            if privacyService.isCameraActive {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }
            if privacyService.isMicrophoneActive {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: privacyService.isCameraActive)
        .animation(.easeInOut(duration: 0.3), value: privacyService.isMicrophoneActive)
        .animation(.easeInOut(duration: 0.3), value: privacyService.isScreenRecording)
    }
}

private struct RecordingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 6, height: 6)
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
