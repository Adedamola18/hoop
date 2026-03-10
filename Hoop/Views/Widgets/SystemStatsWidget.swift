import SwiftUI

struct SystemStatsWidgetView: View {
    let statsService: SystemStatsService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("System")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            HStack(spacing: 12) {
                // CPU
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(String(format: "%.0f%%", statsService.stats.cpuUsage))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(cpuColor)
                        .contentTransition(.numericText())

                    // Mini bar chart
                    HStack(alignment: .bottom, spacing: 1) {
                        ForEach(Array(statsService.cpuHistory.suffix(12).enumerated()), id: \.offset) { _, value in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(barColor(value))
                                .frame(width: 4, height: max(2, CGFloat(value / 100) * 20))
                        }
                    }
                    .frame(height: 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Memory
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(String(format: "%.1f / %.0f GB",
                                statsService.stats.memoryUsedGB,
                                statsService.stats.memoryTotalGB))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))

                    // Pressure bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(memoryColor)
                                .frame(width: geo.size.width * statsService.stats.memoryPressure)
                        }
                    }
                    .frame(height: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private var cpuColor: Color {
        let cpu = statsService.stats.cpuUsage
        if cpu > 80 { return .red }
        if cpu > 50 { return .yellow }
        return .green
    }

    private var memoryColor: Color {
        let pressure = statsService.stats.memoryPressure
        if pressure > 0.85 { return .red }
        if pressure > 0.65 { return .yellow }
        return .green
    }

    private func barColor(_ value: Double) -> Color {
        if value > 80 { return .red.opacity(0.7) }
        if value > 50 { return .yellow.opacity(0.7) }
        return .green.opacity(0.7)
    }
}

// MARK: - Widget Conformance

final class SystemStatsNotchWidget: NotchWidget {
    let id = "systemstats"
    let name = "System Stats"
    let icon = "gauge.with.dots.needle.bottom.50percent"
    let size: WidgetSize = .large

    let statsService: SystemStatsService

    init(statsService: SystemStatsService) {
        self.statsService = statsService
    }

    @MainActor
    func makeBody() -> AnyView {
        AnyView(SystemStatsWidgetView(statsService: statsService))
    }
}
