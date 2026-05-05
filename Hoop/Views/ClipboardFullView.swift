import SwiftUI

struct ClipboardFullView: View {
    let clipboardService: ClipboardService
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            list
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, isActive: true)
        )
        .onExitCommand { onClose() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Clipboard History")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(clipboardService.entries.count)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(.primary.opacity(0.08))
                    )
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search clipboard…", text: Bindable(clipboardService).searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.06))
            )
        }
        .padding(16)
    }

    @ViewBuilder
    private var list: some View {
        let entries = clipboardService.filteredEntries
        if entries.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text(clipboardService.searchQuery.isEmpty
                     ? "No clipboard history yet"
                     : "No matches for \u{201C}\(clipboardService.searchQuery)\u{201D}")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(entries) { entry in
                        ClipboardFullRow(entry: entry, clipboardService: clipboardService)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }
}

private struct ClipboardFullRow: View {
    let entry: ClipboardService.ClipboardEntry
    let clipboardService: ClipboardService

    @State private var isHovered = false
    @State private var copied = false

    var body: some View {
        Button {
            clipboardService.copyToClipboard(entry)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
        } label: {
            HStack(spacing: 12) {
                iconView
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    contentText
                    Text(timeAgo(entry.timestamp))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 6)

                if copied {
                    Label("Copied", systemImage: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else if isHovered {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var iconView: some View {
        switch entry.content {
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.08))
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .fileURL:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.green.opacity(0.15))
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var contentText: some View {
        switch entry.content {
        case .text(let str):
            Text(str)
                .font(.system(size: 12))
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        case .image:
            Text("Image")
                .font(.system(size: 12, weight: .medium))
        case .fileURL(let url):
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
