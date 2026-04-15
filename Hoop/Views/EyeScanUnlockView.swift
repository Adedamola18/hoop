// Hoop/Views/EyeScanUnlockView.swift
import SwiftUI

struct EyeScanUnlockView: View {
    let securityGate: SecurityGate
    let onUnlocked: () -> Void

    @State private var enteredDigits: [Character] = []
    @State private var scanLineOffset: CGFloat = -50
    @State private var irisScale: CGFloat = 0.5
    @State private var irisOpacity: Double = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0
    @State private var successGlow: Double = 0

    private let pinLength = 4 // Minimum PIN length for dot display

    var body: some View {
        VStack(spacing: 16) {
            // Iris graphic
            ZStack {
                irisGraphic
                scanLines
            }
            .frame(width: 80, height: 80)
            .scaleEffect(irisScale * breathingScale)
            .opacity(irisOpacity)
            .offset(x: shakeOffset)
            .drawingGroup()

            // PIN dots
            pinDots

            // Status text
            statusText
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear { animateEntrance() }
        .onKeyPress(characters: .decimalDigits) { keyPress in
            if let char = keyPress.characters.first {
                handleDigit(char)
            }
            return .handled
        }
        .onKeyPress(.delete) {
            if !enteredDigits.isEmpty { enteredDigits.removeLast() }
            return .handled
        }
        .onKeyPress(.return) {
            attemptUnlock()
            return .handled
        }
    }

    // MARK: - Iris Graphic

    private var irisGraphic: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .blue, .purple, .cyan],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 70, height: 70)

            // Middle ring
            Circle()
                .stroke(Color.cyan.opacity(0.6), lineWidth: 2)
                .frame(width: 50, height: 50)

            // Inner ring
            Circle()
                .stroke(Color.blue.opacity(0.8), lineWidth: 1.5)
                .frame(width: 30, height: 30)

            // Center pupil
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.black, .blue.opacity(0.3)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 12
                    )
                )
                .frame(width: 20, height: 20)

            // Success glow
            Circle()
                .fill(Color.green.opacity(successGlow))
                .frame(width: 80, height: 80)
                .blur(radius: 10)
        }
    }

    // MARK: - Scan Lines

    private var scanLines: some View {
        GeometryReader { _ in
            ForEach(0..<5, id: \.self) { i in
                Rectangle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(height: 1)
                    .blur(radius: 0.5)
                    .offset(y: scanLineOffset + CGFloat(i) * 15)
            }
        }
        .clipShape(Circle())
        .frame(width: 70, height: 70)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: true)) {
                scanLineOffset = 50
            }
        }
    }

    // MARK: - PIN Dots

    private var pinDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < enteredDigits.count ? Color.cyan : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(index < enteredDigits.count ? 1.2 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: enteredDigits.count)
            }
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        Group {
            switch securityGate.authPhase {
            case .idle, .scanning:
                Text("Enter PIN")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            case .failure(let remaining):
                Text("\(remaining) attempts remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            case .lockedOut(let until):
                let seconds = max(0, Int(until.timeIntervalSinceNow))
                Text("Locked out. Try again in \(seconds)s")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            case .success:
                Text("Authenticated")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Input

    private func handleDigit(_ char: Character) {
        guard enteredDigits.count < 6 else { return }
        enteredDigits.append(char)
        if enteredDigits.count >= pinLength {
            attemptUnlock()
        }
    }

    private func attemptUnlock() {
        let pin = String(enteredDigits)
        let success = securityGate.attemptUnlock(pin: pin)

        if success {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                successGlow = 0.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onUnlocked()
            }
        } else {
            // Shake animation
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                shakeOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                    shakeOffset = -10
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    shakeOffset = 0
                }
            }
            enteredDigits.removeAll()
        }
    }

    // MARK: - Animations

    private func animateEntrance() {
        withAnimation(.easeOut(duration: 0.3)) {
            irisScale = 1.0
            irisOpacity = 1.0
        }
        // Breathing animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            breathingScale = 1.02
        }
    }
}
