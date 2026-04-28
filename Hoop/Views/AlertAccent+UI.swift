// Hoop/Views/AlertAccent+UI.swift
import SwiftUI

extension AlertAccent {
    var color: Color {
        switch self {
        case .bullish: return .green
        case .bearish: return .red
        case .prediction: return .orange
        }
    }
}
