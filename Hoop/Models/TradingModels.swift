// Hoop/Models/TradingModels.swift
import Foundation
import SwiftUI

// MARK: - Signal Types

enum SignalType: String, Codable {
    case priceAlert
    case predictionShift
    case tradingSignal
}

enum Direction: String, Codable {
    case bullish
    case bearish
    case neutral
}

struct RawSignal {
    let sourceId: String
    let symbol: String
    let signalType: SignalType
    let direction: Direction
    let value: Double
    let changePercent: Double?
    let message: String?
    let timestamp: Date
}

// MARK: - Alert Types

enum AlertPriority: Int, Comparable, Codable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: AlertPriority, rhs: AlertPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AlertAccent: String, Codable {
    case bullish   // green
    case bearish   // red
    case prediction // amber

    var color: Color {
        switch self {
        case .bullish: return .green
        case .bearish: return .red
        case .prediction: return .orange
        }
    }
}

enum AlertState: String, Codable {
    case pending
    case showing
    case dismissed
    case snoozed
}

struct TradingAlert: Identifiable {
    let id: UUID
    let signal: RawSignal
    let priority: AlertPriority
    let accentColor: AlertAccent
    let timestamp: Date
    var state: AlertState

    init(signal: RawSignal, priority: AlertPriority, accentColor: AlertAccent) {
        self.id = UUID()
        self.signal = signal
        self.priority = priority
        self.accentColor = accentColor
        self.timestamp = Date()
        self.state = .pending
    }
}

// MARK: - Adapter Types

enum ConnectionType: String, Codable {
    case websocket
    case polling
    case webhook
}

enum AdapterConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(Error)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Platform Configuration

struct PlatformConfig: Codable {
    var isEnabled: Bool
    var apiKey: String?
    var pollIntervalSeconds: Double
    var activeHoursStart: Int  // hour 0-23
    var activeHoursEnd: Int    // hour 0-23
    var thresholdLow: Double   // % move for low priority
    var thresholdMedium: Double
    var thresholdHigh: Double

    static func defaultConfig(for platformId: String) -> PlatformConfig {
        PlatformConfig(
            isEnabled: false,
            apiKey: nil,
            pollIntervalSeconds: 30,
            activeHoursStart: 0,
            activeHoursEnd: 23,
            thresholdLow: 1.0,
            thresholdMedium: 3.0,
            thresholdHigh: 5.0
        )
    }
}
