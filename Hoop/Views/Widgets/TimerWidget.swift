import SwiftUI

struct TimerWidgetView: View {
    let timerService: TimerService

    var body: some View {
        VStack(spacing: 8) {
            // Mode toggle
            HStack {
                modeButton("Timer", mode: .timer, icon: "timer")
                modeButton("Stopwatch", mode: .stopwatch, icon: "stopwatch")
                Spacer()
            }

            // Display
            Text(timerService.displayString)
                .font(.system(size: 28, weight: .light, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            if timerService.mode == .timer && !timerService.isRunning && timerService.elapsedSeconds == 0 {
                // Preset buttons
                HStack(spacing: 8) {
                    presetButton("1m", minutes: 1)
                    presetButton("5m", minutes: 5)
                    presetButton("10m", minutes: 10)
                    presetButton("25m", minutes: 25)
                }
            }

            // Controls
            HStack(spacing: 12) {
                if timerService.isRunning {
                    controlButton("Pause", icon: "pause.fill", color: .yellow) {
                        timerService.pause()
                    }
                    if timerService.mode == .stopwatch {
                        controlButton("Lap", icon: "flag.fill", color: .blue) {
                            timerService.addLap()
                        }
                    }
                } else {
                    controlButton("Start", icon: "play.fill", color: .green) {
                        timerService.start()
                    }
                    if timerService.elapsedSeconds > 0 {
                        controlButton("Reset", icon: "arrow.counterclockwise", color: .red) {
                            timerService.reset()
                        }
                    }
                }
            }

            // Laps
            if timerService.mode == .stopwatch && !timerService.laps.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(timerService.laps.enumerated()), id: \.offset) { index, lap in
                            Text("L\(index + 1): \(formatLap(lap))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.white.opacity(0.08)))
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.06))
        )
    }

    private func modeButton(_ title: String, mode: TimerService.Mode, icon: String) -> some View {
        Button {
            guard !timerService.isRunning else { return }
            timerService.mode = mode
            timerService.reset()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(timerService.mode == mode ? .white : .white.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(timerService.mode == mode ? .white.opacity(0.15) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func presetButton(_ title: String, minutes: Int) -> some View {
        Button {
            timerService.setPreset(minutes: minutes)
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func controlButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func formatLap(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let centis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, centis)
    }
}

// MARK: - Widget Conformance

final class TimerNotchWidget: NotchWidget {
    let id = "timer"
    let name = "Timer"
    let icon = "timer"
    let size: WidgetSize = .large

    let timerService: TimerService

    init(timerService: TimerService) {
        self.timerService = timerService
    }

    @MainActor
    func makeBody() -> AnyView {
        AnyView(TimerWidgetView(timerService: timerService))
    }
}
