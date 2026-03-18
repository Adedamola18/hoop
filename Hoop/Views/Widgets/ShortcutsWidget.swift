import SwiftUI

struct ShortcutsWidgetView: View {
    let shortcutsService: ShortcutsService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Shortcuts")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                statusIndicator
            }

            if shortcutsService.favorites.isEmpty {
                Text("No favorites — tap ★ to pin shortcuts")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 6) {
                    ForEach(shortcutsService.favorites) { shortcut in
                        shortcutButton(shortcut)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
        .onAppear {
            shortcutsService.loadShortcuts()
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch shortcutsService.runState {
        case .idle:
            EmptyView()
        case .running(let name):
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text(name)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        }
    }

    private func shortcutButton(_ shortcut: ShortcutsService.Shortcut) -> some View {
        Button {
            shortcutsService.runShortcut(shortcut.name)
        } label: {
            Text(shortcut.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget Conformance

final class ShortcutsNotchWidget: NotchWidget {
    let id = "shortcuts"
    let name = "Shortcuts"
    let icon = "bolt.fill"
    let size: WidgetSize = .large

    let shortcutsService: ShortcutsService

    init(shortcutsService: ShortcutsService) {
        self.shortcutsService = shortcutsService
    }

    @MainActor
    func makeBody() -> AnyView {
        AnyView(ShortcutsWidgetView(shortcutsService: shortcutsService))
    }
}
