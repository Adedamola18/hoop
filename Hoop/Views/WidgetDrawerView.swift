import SwiftUI

struct WidgetDrawerView: View {
    let widgetRegistry: WidgetRegistry
    let notchHeight: CGFloat

    var body: some View {
        let enabled = widgetRegistry.enabledWidgets

        VStack(spacing: 0) {
            // Spacer for notch cutout area
            Spacer()
                .frame(height: notchHeight)

            if enabled.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(enabled, id: \.id) { widget in
                            widget.makeBody()
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.3))
            Text("No widgets enabled")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text("Enable widgets in Settings")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
