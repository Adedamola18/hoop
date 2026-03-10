import SwiftUI

struct PrivacyIndicatorView: View {
    let privacyService: PrivacyService

    var body: some View {
        HStack(spacing: 4) {
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
    }
}
