import SwiftUI

/// Arranges collapsed notch indicators by priority.
/// Priority order: privacy (camera/mic/recording) > focus.
/// Gracefully hides lower-priority indicators when space is tight.
struct CollapsedIndicatorBar: View {
    let privacyService: PrivacyService
    let focusService: FocusService
    let alertEngine: AlertEngine

    private var hasPrivacyIndicators: Bool {
        privacyService.isCameraActive || privacyService.isMicrophoneActive || privacyService.isScreenRecording
    }

    private var hasFocus: Bool {
        focusService.isActive
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 140

            HStack {
                // Left: highest-priority indicators (privacy dots)
                if hasPrivacyIndicators {
                    PrivacyIndicatorView(privacyService: privacyService)
                        .padding(.leading, 12)
                }

                if alertEngine.hasUnreadAlerts {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Right: lower-priority indicators
                HStack(spacing: 6) {
                    if hasFocus && !compact {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.purple)
                    }
                }
                .padding(.trailing, 12)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasPrivacyIndicators)
        .animation(.easeInOut(duration: 0.3), value: hasFocus)
    }
}
