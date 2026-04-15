// Hoop/Views/Widgets/TradingAlertsWidget.swift
import SwiftUI

struct TradingAlertsWidgetView: View {
    let alertEngine: AlertEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                Text("Trading Alerts")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if alertEngine.hasUnreadAlerts {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                }
            }

            if alertEngine.recentAlerts.isEmpty {
                Text("No recent alerts")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(alertEngine.recentAlerts.prefix(20)) { alert in
                            alertRow(alert)
                        }
                    }
                }
            }
        }
        .onAppear { alertEngine.markAlertsRead() }
    }

    private func alertRow(_ alert: TradingAlert) -> some View {
        HStack(spacing: 8) {
            // Direction indicator
            Image(systemName: alert.signal.direction == .bullish ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(alert.accentColor.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.signal.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(alert.signal.sourceId.capitalized)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if let change = alert.signal.changePercent {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(alert.accentColor.color)
                }
                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct TradingAlertsWidget: NotchWidget {
    let id = "tradingAlerts"
    let name = "Trading Alerts"
    let icon = "chart.line.uptrend.xyaxis"
    let size: WidgetSize = .large

    let alertEngine: AlertEngine

    @MainActor
    func makeBody() -> AnyView {
        AnyView(TradingAlertsWidgetView(alertEngine: alertEngine))
    }
}
