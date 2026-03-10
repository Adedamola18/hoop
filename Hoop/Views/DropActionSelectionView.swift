import SwiftUI

struct DropActionSelectionView: View {
    let dropActionService: DropActionService

    var body: some View {
        Group {
            switch dropActionService.dropPhase {
            case .idle:
                EmptyView()

            case .selecting(let actions, let urls):
                selectionContent(actions: actions, urls: urls)

            case .executing(let action):
                executingContent(action: action)

            case .result(let result):
                resultContent(result: result)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Selection

    private func selectionContent(actions: [any DropAction], urls: [URL]) -> some View {
        VStack(spacing: 10) {
            Text("Choose Action")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 16) {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    Button {
                        dropActionService.executeAction(action, urls: urls)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: action.iconName)
                                .font(.system(size: 24, weight: .medium))
                            Text(action.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Executing

    private func executingContent(action: any DropAction) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
                .colorScheme(.dark)

            Text("Processing...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Result

    private func resultContent(result: DropActionResult) -> some View {
        VStack(spacing: 8) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(result.success ? .green : .red)

            Text(result.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }
}
