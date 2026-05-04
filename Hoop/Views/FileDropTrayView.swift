import SwiftUI
import UniformTypeIdentifiers

struct FileDropTrayView: View {
    let dropActionService: DropActionService

    var body: some View {
        Group {
            switch dropActionService.dropPhase {
            case .idle:
                trayLayout
            case .selecting(let actions, let urls):
                pickerLayout(actions: actions, urls: urls)
            case .executing(let action):
                executingView(action: action)
            case .result(let result):
                resultView(result: result)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tray (idle)

    private var trayLayout: some View {
        HStack(spacing: 12) {
            DropZonePane(dropActionService: dropActionService)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ActionListPane(dropActionService: dropActionService)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    // MARK: - Multi-match picker (post-drop, several matches)

    private func pickerLayout(actions: [any DropAction], urls: [URL]) -> some View {
        VStack(spacing: 10) {
            Text("Choose Action")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 10) {
                ForEach(actions, id: \.id) { action in
                    Button {
                        dropActionService.executeAction(action, urls: urls)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: action.iconName)
                                .font(.system(size: 22, weight: .medium))
                            Text(action.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Executing

    private func executingView(action: any DropAction) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
                .colorScheme(.dark)
            Text("Processing with \(action.name)…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(12)
    }

    // MARK: - Result

    private func resultView(result: DropActionResult) -> some View {
        VStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(result.success ? Color.green : Color.red)
            Text(result.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }
}

// MARK: - Drop Zone Pane (left)

private struct DropZonePane: View {
    let dropActionService: DropActionService
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(isTargeted ? 0.95 : 0.55))

            VStack(spacing: 2) {
                Text("Drop files here")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isTargeted ? 0.95 : 0.7))
                Text("Auto-routes to a matching action")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(isTargeted ? 0.08 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    .white.opacity(isTargeted ? 0.55 : 0.22),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            DropTrayURLLoader.load(from: providers) { urls in
                guard !urls.isEmpty else { return }
                dropActionService.handleDrop(urls: urls)
            }
            return true
        }
    }
}

// MARK: - Action List Pane (right)

private struct ActionListPane: View {
    let dropActionService: DropActionService

    var body: some View {
        VStack(spacing: 6) {
            ForEach(visibleActions, id: \.id) { action in
                ActionDropRow(action: action) { urls in
                    dropActionService.executeAction(action, urls: urls)
                }
            }

            if visibleActions.isEmpty {
                Text("No actions configured")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Cap to ~5 rows so the tray doesn't outgrow the panel; users can configure
    /// which actions they want via Settings → Drop Actions.
    private var visibleActions: [any DropAction] {
        Array(dropActionService.allActions.prefix(5))
    }
}

private struct ActionDropRow: View {
    let action: any DropAction
    let onDrop: ([URL]) -> Void

    @State private var isTargeted: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    accent.gradient,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )

            Text(action.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(isTargeted ? 0.16 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(isTargeted ? 0.7 : 0.0), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.12), value: isTargeted)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            DropTrayURLLoader.load(from: providers) { urls in
                guard !urls.isEmpty else { return }
                onDrop(urls)
            }
            return true
        }
    }

    private var accent: Color {
        switch action.id {
        case "compress-image": return .blue
        case "ocr-text": return .purple
        case "airdrop": return .indigo
        default:
            // Custom actions and pipelines — color-cycle by id hash for visual variety.
            let palette: [Color] = [.green, .orange, .pink, .teal, .cyan]
            return palette[abs(action.id.hashValue) % palette.count]
        }
    }
}

// MARK: - URL extraction

private enum DropTrayURLLoader {
    static func load(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(urls)
        }
    }
}
