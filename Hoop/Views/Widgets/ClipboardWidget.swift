import SwiftUI

struct ClipboardWidgetView: View {
    let clipboardService: ClipboardService
    let onExpand: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(clipboardService.entries.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                if let onExpand {
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Open full clipboard history")
                }
            }

            // Search
            if clipboardService.entries.count > 3 {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                    TextField("Search...", text: Bindable(clipboardService).searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.06)))
            }

            let items = clipboardService.filteredEntries.prefix(8)
            if items.isEmpty {
                Text("No clipboard history")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(items)) { entry in
                    clipboardRow(entry)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func clipboardRow(_ entry: ClipboardService.ClipboardEntry) -> some View {
        Button {
            clipboardService.copyToClipboard(entry)
        } label: {
            HStack(spacing: 8) {
                entryIcon(entry)
                Text(entry.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Text(timeAgo(entry.timestamp))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func entryIcon(_ entry: ClipboardService.ClipboardEntry) -> some View {
        switch entry.content {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        case .image:
            Image(systemName: "photo")
                .font(.system(size: 9))
                .foregroundStyle(.blue.opacity(0.6))
        case .fileURL:
            Image(systemName: "doc")
                .font(.system(size: 9))
                .foregroundStyle(.green.opacity(0.6))
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }
}

// MARK: - Widget Conformance

final class ClipboardNotchWidget: NotchWidget {
    let id = "clipboard"
    let name = "Clipboard"
    let icon = "doc.on.clipboard"
    let size: WidgetSize = .large

    let clipboardService: ClipboardService
    var onExpand: (() -> Void)?

    init(clipboardService: ClipboardService, onExpand: (() -> Void)? = nil) {
        self.clipboardService = clipboardService
        self.onExpand = onExpand
    }

    @MainActor
    func makeBody() -> AnyView {
        AnyView(ClipboardWidgetView(clipboardService: clipboardService, onExpand: onExpand))
    }
}
