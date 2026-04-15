// Hoop/Services/AlertEngine.swift
import Foundation
import Observation
import UserNotifications

@Observable
final class AlertEngine {

    // MARK: - Observable State

    private(set) var alertQueue: [TradingAlert] = []
    private(set) var currentAlert: TradingAlert?
    private(set) var recentAlerts: [TradingAlert] = []
    private(set) var hasUnreadAlerts = false

    // MARK: - Adapters

    private var adapters: [any MarketAdapter] = []
    private var streamTasks: [Task<Void, Never>] = []
    private(set) var webhookServer: WebhookServer?
    private var webhookStreamTask: Task<Void, Never>?

    // MARK: - Configuration

    private var platformConfigs: [String: PlatformConfig] = [:]
    private var dedupWindow: TimeInterval {
        UserDefaults.standard.object(forKey: "alertDedupWindow") as? TimeInterval ?? 60
    }
    private var recentSignalKeys: [String: Date] = [:] // dedup tracking

    // MARK: - Callbacks

    var onAlert: ((TradingAlert) -> Void)?
    var onAlertDismissed: (() -> Void)?

    // MARK: - Dismiss Timer

    private var dismissTimer: Timer?
    private var alertDismissTimeout: TimeInterval {
        UserDefaults.standard.object(forKey: "alertDismissTimeout") as? TimeInterval ?? 4
    }

    // MARK: - Lifecycle

    func configure(adapters: [any MarketAdapter], webhookServer: WebhookServer) {
        self.adapters = adapters
        self.webhookServer = webhookServer
        loadPlatformConfigs()
    }

    func startObserving() {
        // Start enabled adapters
        for adapter in adapters {
            let config = platformConfigs[adapter.id] ?? PlatformConfig.defaultConfig(for: adapter.id)
            guard config.isEnabled else { continue }

            if let polling = adapter as? PolymarketAdapter {
                polling.pollIntervalSeconds = config.pollIntervalSeconds
            } else if let polling = adapter as? KalshiAdapter {
                polling.pollIntervalSeconds = config.pollIntervalSeconds
            }

            if let binance = adapter as? BinanceAdapter { binance.apiKey = config.apiKey }
            if let bybit = adapter as? BybitAdapter { bybit.apiKey = config.apiKey }

            let task = Task { [weak self] in
                try? await adapter.connect()
                for await signal in adapter.signalStream {
                    await MainActor.run {
                        self?.processSignal(signal)
                    }
                }
            }
            streamTasks.append(task)
        }

        // Start webhook server if enabled
        if UserDefaults.standard.bool(forKey: "webhookEnabled") {
            webhookServer?.start()
            if let server = webhookServer {
                webhookStreamTask = Task { [weak self] in
                    for await signal in server.signalStream {
                        await MainActor.run {
                            self?.processSignal(signal)
                        }
                    }
                }
            }
        }
    }

    func stopObserving() {
        for task in streamTasks { task.cancel() }
        streamTasks.removeAll()
        webhookStreamTask?.cancel()
        webhookStreamTask = nil
        for adapter in adapters { adapter.disconnect() }
        webhookServer?.stop()
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    // MARK: - Signal Processing

    private func processSignal(_ signal: RawSignal) {
        // Active hours check
        let config = platformConfigs[signal.sourceId] ?? PlatformConfig.defaultConfig(for: signal.sourceId)
        guard isWithinActiveHours(config: config) else { return }

        // Deduplication
        let dedupKey = "\(signal.sourceId)|\(signal.symbol)|\(signal.signalType.rawValue)"
        if let lastSeen = recentSignalKeys[dedupKey], Date().timeIntervalSince(lastSeen) < dedupWindow {
            return // Deduplicated
        }
        recentSignalKeys[dedupKey] = Date()

        // Evaluate priority
        let priority = evaluatePriority(signal: signal, config: config)

        // Determine accent color
        let accent: AlertAccent
        switch signal.signalType {
        case .predictionShift: accent = .prediction
        case .priceAlert, .tradingSignal:
            accent = signal.direction == .bullish ? .bullish : .bearish
        }

        let alert = TradingAlert(signal: signal, priority: priority, accentColor: accent)

        // Track in recent alerts (keep last 50)
        recentAlerts.insert(alert, at: 0)
        if recentAlerts.count > 50 { recentAlerts = Array(recentAlerts.prefix(50)) }

        switch priority {
        case .low:
            hasUnreadAlerts = true
        case .medium, .high:
            enqueueAlert(alert)
        }
    }

    private func evaluatePriority(signal: RawSignal, config: PlatformConfig) -> AlertPriority {
        let change = abs(signal.changePercent ?? 0)
        if change >= config.thresholdHigh { return .high }
        if change >= config.thresholdMedium { return .medium }
        return .low
    }

    private func isWithinActiveHours(config: PlatformConfig) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if config.activeHoursStart <= config.activeHoursEnd {
            return hour >= config.activeHoursStart && hour < config.activeHoursEnd
        } else {
            // Wraps midnight (e.g., 22-06)
            return hour >= config.activeHoursStart || hour < config.activeHoursEnd
        }
    }

    // MARK: - Alert Queue

    private func enqueueAlert(_ alert: TradingAlert) {
        if currentAlert == nil {
            showAlert(alert)
        } else if let current = currentAlert, alert.priority > current.priority {
            // Re-queue current, show higher priority
            var requeuedAlert = current
            requeuedAlert.state = .pending
            alertQueue.insert(requeuedAlert, at: 0)
            showAlert(alert)
        } else {
            alertQueue.append(alert)
        }
    }

    private func showAlert(_ alert: TradingAlert) {
        var showing = alert
        showing.state = .showing
        currentAlert = showing
        onAlert?(showing)

        // System notification for high-priority alerts (if enabled)
        if alert.priority == .high && UserDefaults.standard.bool(forKey: "alertSystemNotifications") {
            sendSystemNotification(for: alert)
        }

        // Auto-dismiss medium alerts
        dismissTimer?.invalidate()
        if alert.priority == .medium {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: alertDismissTimeout, repeats: false) { [weak self] _ in
                self?.dismissCurrentAlert()
            }
        }
    }

    // MARK: - System Notifications

    private func sendSystemNotification(for alert: TradingAlert) {
        let content = UNMutableNotificationContent()
        content.title = "\(alert.signal.sourceId.capitalized): \(alert.signal.symbol)"
        let changeStr = alert.signal.changePercent.map { String(format: "%+.1f%%", $0) } ?? ""
        content.body = "\(alert.signal.signalType == .predictionShift ? "Probability" : "Price"): \(String(format: "%.2f", alert.signal.value)) \(changeStr)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func dismissCurrentAlert() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentAlert = nil
        onAlertDismissed?()

        // Show next in queue
        if !alertQueue.isEmpty {
            let next = alertQueue.removeFirst()
            showAlert(next)
        }
    }

    var snoozeDurationSeconds: TimeInterval {
        UserDefaults.standard.object(forKey: "alertSnoozeDuration") as? TimeInterval ?? 300
    }

    func snoozeCurrentAlert(duration: TimeInterval? = nil) {
        let snoozeDuration = duration ?? snoozeDurationSeconds
        guard var alert = currentAlert else { return }
        alert.state = .snoozed
        dismissTimer?.invalidate()
        dismissTimer = nil
        currentAlert = nil
        onAlertDismissed?()

        // Re-insert after snooze duration
        Timer.scheduledTimer(withTimeInterval: snoozeDuration, repeats: false) { [weak self] _ in
            alert.state = .pending
            self?.enqueueAlert(alert)
        }

        // Show next in queue
        if !alertQueue.isEmpty {
            let next = alertQueue.removeFirst()
            showAlert(next)
        }
    }

    @MainActor
    func connectionState(for adapterId: String) -> AdapterConnectionState {
        adapters.first(where: { $0.id == adapterId })?.connectionState ?? .disconnected
    }

    func markAlertsRead() {
        hasUnreadAlerts = false
    }

    // MARK: - Configuration Persistence

    private func loadPlatformConfigs() {
        guard let data = UserDefaults.standard.data(forKey: "platformConfigs"),
              let configs = try? JSONDecoder().decode([String: PlatformConfig].self, from: data) else {
            // Initialize defaults
            for adapter in adapters {
                platformConfigs[adapter.id] = PlatformConfig.defaultConfig(for: adapter.id)
            }
            return
        }
        platformConfigs = configs
    }

    func savePlatformConfigs() {
        if let data = try? JSONEncoder().encode(platformConfigs) {
            UserDefaults.standard.set(data, forKey: "platformConfigs")
        }
    }

    func config(for adapterId: String) -> PlatformConfig {
        platformConfigs[adapterId] ?? PlatformConfig.defaultConfig(for: adapterId)
    }

    func updateConfig(for adapterId: String, _ config: PlatformConfig) {
        platformConfigs[adapterId] = config
        savePlatformConfigs()
    }
}
