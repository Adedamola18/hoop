import SwiftUI

/// Shown in the expanded notch when no media is playing and no widgets are enabled.
/// Displays app branding and version info as a friendly idle state.
struct AboutNotchView: View {
    var notchHeight: CGFloat = 0

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Spacer for notch cutout area
            Spacer()
                .frame(height: notchHeight)

            VStack(spacing: 12) {
                // App icon
                Image(systemName: "sparkle")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 4) {
                    Text("Hoop")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("Your notch, upgraded")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text("v\(appVersion)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
