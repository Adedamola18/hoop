// Hoop/Services/StartupAnimator.swift
import Foundation
import Observation

@Observable
final class StartupAnimator {

    enum Phase {
        case typewriter
        case pulse
        case done
    }
    

    private(set) var phase: Phase = .typewriter
    private(set) var visibleCharacters: Int = 0
    private var hasPlayedStartup = false
    private var typewriterTimer: Timer?
    private var phaseTimer: Timer?

    private let text = "Hoop"
    private let characterInterval: TimeInterval = 0.375
    private let pulseDuration: TimeInterval = 1.0

    var onComplete: (() -> Void)?

    var displayText: String {
        String(text.prefix(visibleCharacters))
    }

    var showCursor: Bool {
        phase == .typewriter
    }

    func start() {
        guard !hasPlayedStartup else {
            onComplete?()
            return
        }
        hasPlayedStartup = true
        phase = .typewriter
        visibleCharacters = 0
        startTypewriter()
    }

    func skip() {
        hasPlayedStartup = true
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        phaseTimer?.invalidate()
        phaseTimer = nil
        phase = .done
        onComplete?()
    }

    private func startTypewriter() {
        typewriterTimer = Timer.scheduledTimer(withTimeInterval: characterInterval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.visibleCharacters += 1
            if self.visibleCharacters >= self.text.count {
                timer.invalidate()
                self.typewriterTimer = nil
                self.transitionToPulse()
            }
        }
    }

    private func transitionToPulse() {
        phase = .pulse
        phaseTimer = Timer.scheduledTimer(withTimeInterval: pulseDuration, repeats: false) { [weak self] _ in
            self?.phase = .done
            self?.onComplete?()
        }
    }
}
