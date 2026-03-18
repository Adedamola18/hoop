import SwiftUI

struct BatteryIndicator: View {
    let batteryService: BatteryService

    private var info: BatteryService.BatteryInfo { batteryService.battery }

    private var color: Color {
        if info.isCharging { return .green }
        if info.percentage > 50 { return .green }
        if info.percentage > 20 { return .yellow }
        return .red
    }

    private var isLowBattery: Bool {
        info.percentage <= 10 && !info.isCharging
    }

    var body: some View {
        if info.isValid {
            HStack(spacing: 3) {
                if info.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                }
                Text("\(info.percentage)%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
            }
            .opacity(isLowBattery ? 0.5 : 1.0)
            .animation(
                isLowBattery ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: isLowBattery
            )
        }
    }
}
