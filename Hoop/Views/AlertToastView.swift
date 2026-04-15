// Hoop/Views/AlertToastView.swift
import SwiftUI

struct AlertToastView: View {
    let alert: TradingAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Platform icon
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(alert.accentColor.color)

            // Direction arrow
            Image(systemName: alert.signal.direction == .bullish ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(alert.accentColor.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.signal.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let change = alert.signal.changePercent {
                Text(String(format: "%+.1f%%", change))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(alert.accentColor.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onTapGesture { onDismiss() }
    }

    private var iconName: String {
        switch alert.signal.sourceId {
        case "binance", "bybit": return "chart.line.uptrend.xyaxis"
        case "polymarket", "kalshi": return "chart.pie"
        case "webhook": return "antenna.radiowaves.left.and.right"
        default: return "bell"
        }
    }

    private var summaryText: String {
        let price = String(format: "%.2f", alert.signal.value)
        switch alert.signal.signalType {
        case .priceAlert: return "$\(price)"
        case .predictionShift: return "\(price)% probability"
        case .tradingSignal: return alert.signal.message ?? "$\(price)"
        }
    }
}
