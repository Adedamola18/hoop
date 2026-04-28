// Hoop/Views/AlertDetailView.swift
import SwiftUI

struct AlertDetailView: View {
    let alert: TradingAlert
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(alert.accentColor.color)

                Text(alert.signal.sourceId.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Main content
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.signal.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(2)

                    Text(detailText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceText)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))

                    if let change = alert.signal.changePercent {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(alert.accentColor.color)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)

                Button(action: onSnooze) {
                    Label("Snooze", systemImage: "bell.slash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onOpenInBrowser) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var iconName: String {
        switch alert.signal.sourceId {
        case "binance", "bybit": return "chart.line.uptrend.xyaxis"
        case "polymarket", "kalshi": return "chart.pie"
        case "webhook": return "antenna.radiowaves.left.and.right"
        default: return "bell"
        }
    }

    private var priceText: String {
        switch alert.signal.signalType {
        case .predictionShift: return String(format: "%.0f%%", alert.signal.value)
        default: return String(format: "$%.2f", alert.signal.value)
        }
    }

    private var detailText: String {
        switch alert.signal.signalType {
        case .priceAlert: return "Price Alert"
        case .predictionShift: return "Prediction Market"
        case .tradingSignal: return alert.signal.message ?? "Trading Signal"
        }
    }
}
