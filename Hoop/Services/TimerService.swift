import AppKit
import Foundation
import Observation

@Observable
final class TimerService {

    enum Mode: String {
        case timer
        case stopwatch
    }

    var mode: Mode = .timer
    var isRunning: Bool = false
    var elapsedSeconds: TimeInterval = 0
    var targetSeconds: TimeInterval = 300  // default 5 min
    var laps: [TimeInterval] = []

    private var tickTimer: Timer?
    private var startDate: Date?
    private var accumulatedBeforePause: TimeInterval = 0

    // MARK: - Timer Mode

    var remainingSeconds: TimeInterval {
        max(0, targetSeconds - elapsedSeconds)
    }

    var isTimerComplete: Bool {
        mode == .timer && isRunning && remainingSeconds <= 0
    }

    var displayString: String {
        let seconds: TimeInterval
        if mode == .timer {
            seconds = remainingSeconds
        } else {
            seconds = elapsedSeconds
        }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let centis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "%d.%02d", secs, centis)
    }

    func setPreset(minutes: Int) {
        guard !isRunning else { return }
        targetSeconds = TimeInterval(minutes * 60)
        elapsedSeconds = 0
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startDate = Date()
        accumulatedBeforePause = elapsedSeconds

        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        accumulatedBeforePause = elapsedSeconds
        startDate = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    func reset() {
        pause()
        elapsedSeconds = 0
        accumulatedBeforePause = 0
        laps.removeAll()
    }

    // MARK: - Stopwatch Mode

    func addLap() {
        guard mode == .stopwatch, isRunning else { return }
        laps.append(elapsedSeconds)
    }

    // MARK: - Private

    private func tick() {
        guard let start = startDate else { return }
        elapsedSeconds = accumulatedBeforePause + Date().timeIntervalSince(start)

        if mode == .timer && remainingSeconds <= 0 {
            pause()
            playCompletionSound()
        }
    }

    private func playCompletionSound() {
        NSSound(named: .init("Ping"))?.play()
    }
}
