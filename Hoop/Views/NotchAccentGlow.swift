// Hoop/Views/NotchAccentGlow.swift
import SwiftUI

struct NotchAccentGlow: ViewModifier {
    let accent: AlertAccent?
    let isActive: Bool

    @State private var glowOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .shadow(color: accentColor.opacity(glowOpacity), radius: 12, x: 0, y: 2)
            .shadow(color: accentColor.opacity(glowOpacity * 0.5), radius: 24, x: 0, y: 4)
            .onChange(of: isActive) { _, active in
                withAnimation(.easeInOut(duration: active ? 0.3 : 0.5)) {
                    glowOpacity = active ? 0.7 : 0
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.easeIn(duration: 0.3)) { glowOpacity = 0.7 }
                }
            }
    }

    private var accentColor: Color {
        accent?.color ?? .clear
    }
}

extension View {
    func notchAccentGlow(accent: AlertAccent?, isActive: Bool) -> some View {
        modifier(NotchAccentGlow(accent: accent, isActive: isActive))
    }
}
