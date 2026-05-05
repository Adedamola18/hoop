# NotchNook v2 Feature Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add startup animation, live trading alerts from crypto/prediction markets, and PIN-secured eye-scan unlock to NotchNook's macOS notch utility.

**Architecture:** Platform Adapter Pattern -- each market gets an isolated adapter conforming to `MarketAdapter` protocol. `AlertEngine` orchestrates adapters, evaluates priorities, manages the alert queue. `SecurityGate` manages PIN via Keychain and drives the eye-scan unlock animation. All new services are `@Observable`, owned by `NotchWindowManager`, following the established service-ownership pattern.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSPanel), Network framework (NWListener), URLSession WebSocket, Observation framework, Security framework (Keychain), CryptoKit (SHA-256)

**Spec:** `docs/superpowers/specs/2026-03-18-notchnook-v2-expansion-design.md`

---

## File Map

### New Files (16)

| File | Responsibility |
|------|---------------|
| `Hoop/Models/TradingModels.swift` | RawSignal, TradingAlert, AlertPriority, AlertAccent, AlertState, SignalType, Direction, ConnectionType, AdapterConnectionState enums and structs |
| `Hoop/Services/StartupAnimator.swift` | Typewriter + pulse animation phases, Timer-driven character reveal |
| `Hoop/Services/AlertEngine.swift` | Adapter lifecycle, priority evaluation, active hours, alert queue, dedup |
| `Hoop/Services/SecurityGate.swift` | PIN hash via Keychain, lock state, auth phases, auto-lock timer |
| `Hoop/Services/WebhookServer.swift` | NWListener localhost HTTP server, TradingView JSON parsing |
| `Hoop/Services/Adapters/MarketAdapter.swift` | MarketAdapter protocol definition |
| `Hoop/Services/Adapters/BinanceAdapter.swift` | WebSocket connection to Binance streams |
| `Hoop/Services/Adapters/BybitAdapter.swift` | WebSocket connection to Bybit streams |
| `Hoop/Services/Adapters/PolymarketAdapter.swift` | REST polling Polymarket public API |
| `Hoop/Services/Adapters/KalshiAdapter.swift` | REST polling Kalshi public API |
| `Hoop/Views/AlertToastView.swift` | Medium-priority alert toast (400x60pt) |
| `Hoop/Views/AlertDetailView.swift` | High-priority expanded alert with action buttons |
| `Hoop/Views/NotchAccentGlow.swift` | Colored glow view modifier for NotchShape |
| `Hoop/Views/EyeScanUnlockView.swift` | Cinematic iris animation + PIN dot entry |
| `Hoop/Views/Widgets/TradingAlertsWidget.swift` | Alert feed widget for WidgetDrawer |

### Modified Files (7)

| File | Changes |
|------|---------|
| `Hoop/Models/NotchState.swift` | Add `.alert` to Phase enum, add `activeAlert: TradingAlert?` and `previousPhaseBeforeAlert: Phase?` properties |
| `Hoop/HoopApp.swift` | Pass services from AppDelegate to SettingsView via @Environment |
| `Hoop/Views/NotchRootView.swift` | Add startup animation, security gate, alert phase to render chain; add new service parameters; update `isActive` to include `.alert` |
| `Hoop/Views/SettingsView.swift` | Add Markets tab, Security section under General |
| `Hoop/Views/Widgets/CollapsedIndicatorBar.swift` | Add trading alert dot indicator |
| `Hoop/Window/NotchWindowManager.swift` | Own new services, register widget, wire callbacks, alert queue coordination |
| `Hoop.xcodeproj/project.pbxproj` | Register all 15 new Swift files (PBXFileReference, PBXBuildFile, PBXGroup, PBXSourcesBuildPhase) |

---

## Task 1: Data Models & Protocol Foundation

**Files:**
- Create: `Hoop/Models/TradingModels.swift`
- Create: `Hoop/Services/Adapters/MarketAdapter.swift`
- Modify: `Hoop/Models/NotchState.swift`

This task lays the type foundation that everything else depends on. No UI, no networking -- just types.

- [ ] **Step 1: Create TradingModels.swift**

```swift
// Hoop/Models/TradingModels.swift
import Foundation

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
            activeHoursEnd: 24,
            thresholdLow: 1.0,
            thresholdMedium: 3.0,
            thresholdHigh: 5.0
        )
    }
}
```

Add `import SwiftUI` at the top for the `Color` reference in `AlertAccent`.

- [ ] **Step 2: Create MarketAdapter.swift protocol**

```swift
// Hoop/Services/Adapters/MarketAdapter.swift
import Foundation

protocol MarketAdapter: AnyObject {
    var id: String { get }
    var name: String { get }
    var connectionType: ConnectionType { get }
    var connectionState: AdapterConnectionState { get }

    func connect() async throws
    func disconnect()

    var signalStream: AsyncStream<RawSignal> { get }
}
```

- [ ] **Step 3: Add `.alert` phase and alert properties to NotchState.swift**

In `Hoop/Models/NotchState.swift`, add the `.alert` case to the Phase enum (after `.hud`):

```swift
// In Phase enum, add:
case alert
```

Add two new properties to the NotchState class (after `contentPadding`):

```swift
var activeAlert: TradingAlert?
var previousPhaseBeforeAlert: Phase?
```

- [ ] **Step 4: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Models/NotchState.swift Hoop/Services/Adapters/MarketAdapter.swift`

Fix any errors. Note: `TradingModels.swift` needs `import SwiftUI` for the Color reference.

- [ ] **Step 5: Commit**

```bash
git add Hoop/Models/TradingModels.swift Hoop/Services/Adapters/MarketAdapter.swift Hoop/Models/NotchState.swift
git commit -m "feat: add trading models, MarketAdapter protocol, and .alert phase"
```

---

## Task 2: StartupAnimator Service

**Files:**
- Create: `Hoop/Services/StartupAnimator.swift`

Self-contained service with no dependencies on other new code.

- [ ] **Step 1: Create StartupAnimator.swift**

```swift
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
            phase = .done
            return
        }
        hasPlayedStartup = true
        phase = .typewriter
        visibleCharacters = 0
        startTypewriter()
    }

    func skip() {
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
```

- [ ] **Step 2: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Services/StartupAnimator.swift`

- [ ] **Step 3: Commit**

```bash
git add Hoop/Services/StartupAnimator.swift
git commit -m "feat: add StartupAnimator service with typewriter + pulse phases"
```

---

## Task 3: SecurityGate Service

**Files:**
- Create: `Hoop/Services/SecurityGate.swift`

Depends on TradingModels.swift (from Task 1) only for type references. Keychain + lock state logic.

- [ ] **Step 1: Create SecurityGate.swift**

```swift
// Hoop/Services/SecurityGate.swift
import AppKit
import Foundation
import Observation
import Security
import CryptoKit

@Observable
final class SecurityGate {

    enum AuthPhase {
        case idle
        case scanning
        case success
        case failure(attemptsRemaining: Int)
        case lockedOut(until: Date)
    }

    private(set) var authPhase: AuthPhase = .idle
    private(set) var isUnlocked: Bool = false
    private(set) var isPINConfigured: Bool = false

    var protectedWidgetIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "protectedWidgetIds") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "protectedWidgetIds")
        }
    }

    var autoLockTimeoutMinutes: Int {
        UserDefaults.standard.object(forKey: "autoLockTimeout") as? Int ?? 5
    }

    var lockOnSleep: Bool {
        UserDefaults.standard.object(forKey: "lockOnSleep") as? Bool ?? true
    }

    private var failedAttempts = 0
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 30
    private var autoLockTimer: Timer?
    private var lockoutTimer: Timer?
    private var sleepObserver: Any?

    private let keychainService = "com.hoops.notchnook.securitygate"
    private let keychainAccount = "pin-hash"

    var onLockStateChanged: (() -> Void)?

    // MARK: - Lifecycle

    func startObserving() {
        isPINConfigured = loadPINHash() != nil

        // Default-protect trading alerts widget on first setup
        if isPINConfigured && !UserDefaults.standard.bool(forKey: "securityDefaultsApplied") {
            var ids = protectedWidgetIds
            ids.insert("tradingAlerts")
            protectedWidgetIds = ids
            UserDefaults.standard.set(true, forKey: "securityDefaultsApplied")
        }

        if lockOnSleep {
            sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.lock()
            }
        }
    }

    func stopObserving() {
        autoLockTimer?.invalidate()
        autoLockTimer = nil
        lockoutTimer?.invalidate()
        lockoutTimer = nil
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            sleepObserver = nil
        }
    }

    // MARK: - Lock/Unlock

    func isProtected(_ widgetId: String) -> Bool {
        isPINConfigured && protectedWidgetIds.contains(widgetId)
    }

    func lock() {
        isUnlocked = false
        authPhase = .idle
        autoLockTimer?.invalidate()
        autoLockTimer = nil
        onLockStateChanged?()
    }

    func attemptUnlock(pin: String) -> Bool {
        guard isPINConfigured else { return false }

        if case .lockedOut(let until) = authPhase {
            if Date() < until { return false }
            failedAttempts = 0
        }

        authPhase = .scanning

        let inputHash = hashPIN(pin)
        guard let storedHash = loadPINHash(), inputHash == storedHash else {
            failedAttempts += 1
            let remaining = maxAttempts - failedAttempts
            if remaining <= 0 {
                let lockoutEnd = Date().addingTimeInterval(lockoutDuration)
                authPhase = .lockedOut(until: lockoutEnd)
                lockoutTimer = Timer.scheduledTimer(withTimeInterval: lockoutDuration, repeats: false) { [weak self] _ in
                    self?.failedAttempts = 0
                    self?.authPhase = .idle
                }
            } else {
                authPhase = .failure(attemptsRemaining: remaining)
            }
            return false
        }

        // Success
        authPhase = .success
        isUnlocked = true
        failedAttempts = 0
        resetAutoLockTimer()
        onLockStateChanged?()
        return true
    }

    func resetAutoLockTimer() {
        autoLockTimer?.invalidate()
        let timeout = autoLockTimeoutMinutes
        guard timeout > 0 else { return } // 0 = never
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeout * 60), repeats: false) { [weak self] _ in
            self?.lock()
        }
    }

    // MARK: - PIN Management

    func setupPIN(_ pin: String) -> Bool {
        let hash = hashPIN(pin)
        let saved = savePINHash(hash)
        if saved {
            isPINConfigured = true
            // Default-protect trading alerts
            var ids = protectedWidgetIds
            ids.insert("tradingAlerts")
            protectedWidgetIds = ids
            UserDefaults.standard.set(true, forKey: "securityDefaultsApplied")
        }
        return saved
    }

    func changePIN(currentPIN: String, newPIN: String) -> Bool {
        let currentHash = hashPIN(currentPIN)
        guard let storedHash = loadPINHash(), currentHash == storedHash else {
            return false
        }
        deletePINHash()
        return setupPIN(newPIN)
    }

    // MARK: - Keychain

    private func hashPIN(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func savePINHash(_ hash: String) -> Bool {
        deletePINHash() // Remove old if exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: Data(hash.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func loadPINHash() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deletePINHash() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 -framework AppKit Hoop/Services/SecurityGate.swift`

- [ ] **Step 3: Commit**

```bash
git add Hoop/Services/SecurityGate.swift
git commit -m "feat: add SecurityGate service with Keychain PIN and lock state"
```

---

## Task 4: WebhookServer

**Files:**
- Create: `Hoop/Services/WebhookServer.swift`

Depends on TradingModels.swift (Task 1) for RawSignal.

- [ ] **Step 1: Create WebhookServer.swift**

```swift
// Hoop/Services/WebhookServer.swift
import Foundation
import Network
import Observation

@Observable
final class WebhookServer {

    private(set) var isRunning = false
    private var listener: NWListener?
    private var continuation: AsyncStream<RawSignal>.Continuation?

    private(set) lazy var signalStream: AsyncStream<RawSignal> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    var port: UInt16 {
        UInt16(UserDefaults.standard.object(forKey: "webhookPort") as? Int ?? 9876)
    }

    var bearerToken: String? {
        let token = UserDefaults.standard.string(forKey: "webhookBearerToken")
        return token?.isEmpty == true ? nil : token
    }

    func start() {
        guard !isRunning else { return }
        do {
            let params = NWParameters.tcp
            let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(rawValue: 9876)!
            listener = try NWListener(using: params, on: nwPort)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                case .failed, .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                // Enforce localhost-only: reject non-loopback connections
                if case .hostPort(let host, _) = connection.endpoint {
                    let hostStr = "\(host)"
                    if hostStr != "127.0.0.1" && hostStr != "::1" && hostStr != "localhost" {
                        connection.cancel()
                        return
                    }
                }
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        continuation?.finish()
    }

    func sendTestAlert() {
        let signal = RawSignal(
            sourceId: "webhook",
            symbol: "TEST/ALERT",
            signalType: .tradingSignal,
            direction: .bullish,
            value: 100.0,
            changePercent: 5.0,
            message: "Test alert from webhook server",
            timestamp: Date()
        )
        continuation?.yield(signal)
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            defer { connection.cancel() }
            guard let self, let data else { return }

            let httpString = String(data: data, encoding: .utf8) ?? ""

            // Verify POST method
            guard httpString.hasPrefix("POST") else {
                self.sendHTTPResponse(connection: connection, status: 405, body: "Method Not Allowed")
                return
            }

            // Check bearer token if configured
            if let expectedToken = self.bearerToken {
                guard httpString.contains("Authorization: Bearer \(expectedToken)") else {
                    self.sendHTTPResponse(connection: connection, status: 401, body: "Unauthorized")
                    return
                }
            }

            // Extract JSON body (after double newline)
            guard let bodyRange = httpString.range(of: "\r\n\r\n") ?? httpString.range(of: "\n\n") else {
                self.sendHTTPResponse(connection: connection, status: 400, body: "No body")
                return
            }

            let bodyString = String(httpString[bodyRange.upperBound...])
            guard let bodyData = bodyString.data(using: .utf8) else {
                self.sendHTTPResponse(connection: connection, status: 400, body: "Invalid body")
                return
            }

            if let signal = self.parseTradingViewPayload(bodyData) {
                self.continuation?.yield(signal)
                self.sendHTTPResponse(connection: connection, status: 200, body: "OK")
            } else {
                self.sendHTTPResponse(connection: connection, status: 400, body: "Parse error")
            }
        }
    }

    private func parseTradingViewPayload(_ data: Data) -> RawSignal? {
        // TradingView webhook format: {"ticker": "BTCUSDT", "action": "buy"/"sell", "price": 70000, "message": "..."}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let symbol = json["ticker"] as? String ?? json["symbol"] as? String ?? "UNKNOWN"
        let action = json["action"] as? String ?? ""
        let price = json["price"] as? Double ?? json["close"] as? Double ?? 0
        let message = json["message"] as? String ?? json["comment"] as? String

        let direction: Direction
        switch action.lowercased() {
        case "buy", "long": direction = .bullish
        case "sell", "short": direction = .bearish
        default: direction = .neutral
        }

        return RawSignal(
            sourceId: "webhook",
            symbol: symbol,
            signalType: .tradingSignal,
            direction: direction,
            value: price,
            changePercent: nil,
            message: message,
            timestamp: Date()
        )
    }

    private func sendHTTPResponse(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 405: statusText = "Method Not Allowed"
        default: statusText = "Error"
        }
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Services/WebhookServer.swift`

- [ ] **Step 3: Commit**

```bash
git add Hoop/Services/WebhookServer.swift
git commit -m "feat: add WebhookServer with TradingView-compatible localhost HTTP listener"
```

---

## Task 5: Platform Adapters (Binance, Bybit, Polymarket, Kalshi)

**Files:**
- Create: `Hoop/Services/Adapters/BinanceAdapter.swift`
- Create: `Hoop/Services/Adapters/BybitAdapter.swift`
- Create: `Hoop/Services/Adapters/PolymarketAdapter.swift`
- Create: `Hoop/Services/Adapters/KalshiAdapter.swift`

All depend on MarketAdapter protocol and TradingModels (Task 1).

- [ ] **Step 1: Create BinanceAdapter.swift**

```swift
// Hoop/Services/Adapters/BinanceAdapter.swift
import Foundation

final class BinanceAdapter: MarketAdapter {
    let id = "binance"
    let name = "Binance"
    let connectionType: ConnectionType = .websocket

    private(set) var connectionState: AdapterConnectionState = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private(set) lazy var signalStream: AsyncStream<RawSignal> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    var apiKey: String?
    var watchedSymbols: [String] = ["btcusdt", "ethusdt"]

    func connect() async throws {
        connectionState = .connecting
        reconnectAttempts = 0

        let streams = watchedSymbols.map { "\($0)@ticker" }.joined(separator: "/")
        guard let url = URL(string: "wss://stream.binance.com:9443/ws/\(streams)") else {
            connectionState = .failed(URLError(.badURL))
            return
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        connectionState = .connected
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message, let data = text.data(using: .utf8) {
                    if let signal = self.parseTickerMessage(data) {
                        self.continuation?.yield(signal)
                    }
                }
                self.reconnectAttempts = 0
                self.receiveMessages() // Continue receiving
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func parseTickerMessage(_ data: Data) -> RawSignal? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let symbol = json["s"] as? String,
              let priceStr = json["c"] as? String, let price = Double(priceStr),
              let changeStr = json["P"] as? String, let changePercent = Double(changeStr) else { return nil }

        let direction: Direction = changePercent >= 0 ? .bullish : .bearish

        return RawSignal(
            sourceId: id,
            symbol: symbol,
            signalType: .priceAlert,
            direction: direction,
            value: price,
            changePercent: changePercent,
            message: nil,
            timestamp: Date()
        )
    }

    private func handleDisconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .failed(URLError(.networkConnectionLost))
            return
        }
        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { try? await self?.connect() }
        }
    }
}
```

- [ ] **Step 2: Create BybitAdapter.swift**

```swift
// Hoop/Services/Adapters/BybitAdapter.swift
import Foundation

final class BybitAdapter: MarketAdapter {
    let id = "bybit"
    let name = "Bybit"
    let connectionType: ConnectionType = .websocket

    private(set) var connectionState: AdapterConnectionState = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private(set) lazy var signalStream: AsyncStream<RawSignal> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    var apiKey: String?
    var watchedSymbols: [String] = ["BTCUSDT", "ETHUSDT"]

    func connect() async throws {
        connectionState = .connecting
        reconnectAttempts = 0

        guard let url = URL(string: "wss://stream.bybit.com/v5/public/spot") else {
            connectionState = .failed(URLError(.badURL))
            return
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Subscribe to tickers
        let args = watchedSymbols.map { "\"tickers.\($0)\"" }.joined(separator: ",")
        let subMessage = "{\"op\":\"subscribe\",\"args\":[\(args)]}"
        try? await webSocketTask?.send(.string(subMessage))

        connectionState = .connected
        receiveMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message, let data = text.data(using: .utf8) {
                    if let signal = self.parseTickerMessage(data) {
                        self.continuation?.yield(signal)
                    }
                }
                self.reconnectAttempts = 0
                self.receiveMessages()
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func parseTickerMessage(_ data: Data) -> RawSignal? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let topic = json["topic"] as? String, topic.hasPrefix("tickers"),
              let dataDict = json["data"] as? [String: Any],
              let symbol = dataDict["symbol"] as? String,
              let priceStr = dataDict["lastPrice"] as? String, let price = Double(priceStr),
              let changeStr = dataDict["price24hPcnt"] as? String, let changePct = Double(changeStr)
        else { return nil }

        let direction: Direction = changePct >= 0 ? .bullish : .bearish

        return RawSignal(
            sourceId: id,
            symbol: symbol,
            signalType: .priceAlert,
            direction: direction,
            value: price,
            changePercent: changePct * 100,
            message: nil,
            timestamp: Date()
        )
    }

    private func handleDisconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .failed(URLError(.networkConnectionLost))
            return
        }
        reconnectAttempts += 1
        connectionState = .reconnecting(attempt: reconnectAttempts)
        let delay = min(pow(2.0, Double(reconnectAttempts)), 60.0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { try? await self?.connect() }
        }
    }
}
```

- [ ] **Step 3: Create PolymarketAdapter.swift**

```swift
// Hoop/Services/Adapters/PolymarketAdapter.swift
import Foundation

final class PolymarketAdapter: MarketAdapter {
    let id = "polymarket"
    let name = "Polymarket"
    let connectionType: ConnectionType = .polling

    private(set) var connectionState: AdapterConnectionState = .disconnected
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var pollTimer: Timer?
    private var previousPrices: [String: Double] = [:]
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private(set) lazy var signalStream: AsyncStream<RawSignal> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    var watchedMarketSlugs: [String] = []
    var pollIntervalSeconds: TimeInterval = 30

    func connect() async throws {
        connectionState = .connecting
        reconnectAttempts = 0
        connectionState = .connected
        startPolling()
    }

    func disconnect() {
        pollTimer?.invalidate()
        pollTimer = nil
        connectionState = .disconnected
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { await self?.fetchMarkets() }
        }
        Task { await fetchMarkets() } // Immediate first fetch
    }

    private func fetchMarkets() async {
        guard !watchedMarketSlugs.isEmpty else { return }

        // Polymarket CLOB API - batch fetch
        guard let url = URL(string: "https://clob.polymarket.com/markets") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Handle rate limiting
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                connectionState = .reconnecting(attempt: reconnectAttempts)
                reconnectAttempts += 1
                if reconnectAttempts < maxReconnectAttempts {
                    let backoff = min(pow(2.0, Double(reconnectAttempts)), 60.0)
                    try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                } else {
                    connectionState = .failed(URLError(.resourceUnavailable))
                }
                return
            }

            reconnectAttempts = 0
            connectionState = .connected

            guard let markets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

            for market in markets {
                guard let slug = market["condition_id"] as? String ?? market["question_id"] as? String,
                      watchedMarketSlugs.contains(slug),
                      let question = market["question"] as? String,
                      let priceStr = market["price"] as? String ?? (market["tokens"] as? [[String: Any]])?.first?["price"] as? String,
                      let price = Double(priceStr)
                else { continue }

                let previousPrice = previousPrices[slug] ?? price
                let changePct = previousPrice > 0 ? ((price - previousPrice) / previousPrice) * 100 : 0
                previousPrices[slug] = price

                guard abs(changePct) > 0.1 else { continue } // Skip negligible changes

                let direction: Direction = changePct >= 0 ? .bullish : .bearish

                let signal = RawSignal(
                    sourceId: id,
                    symbol: question,
                    signalType: .predictionShift,
                    direction: direction,
                    value: price * 100, // Convert to percentage
                    changePercent: changePct,
                    message: nil,
                    timestamp: Date()
                )
                continuation?.yield(signal)
            }
        } catch {
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                connectionState = .reconnecting(attempt: reconnectAttempts)
            } else {
                connectionState = .failed(error)
            }
        }
    }
}
```

- [ ] **Step 4: Create KalshiAdapter.swift**

```swift
// Hoop/Services/Adapters/KalshiAdapter.swift
import Foundation

final class KalshiAdapter: MarketAdapter {
    let id = "kalshi"
    let name = "Kalshi"
    let connectionType: ConnectionType = .polling

    private(set) var connectionState: AdapterConnectionState = .disconnected
    private var continuation: AsyncStream<RawSignal>.Continuation?
    private var pollTimer: Timer?
    private var previousPrices: [String: Double] = [:]
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    private(set) lazy var signalStream: AsyncStream<RawSignal> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    var watchedTickers: [String] = []
    var pollIntervalSeconds: TimeInterval = 30

    func connect() async throws {
        connectionState = .connecting
        reconnectAttempts = 0
        connectionState = .connected
        startPolling()
    }

    func disconnect() {
        pollTimer?.invalidate()
        pollTimer = nil
        connectionState = .disconnected
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollIntervalSeconds, repeats: true) { [weak self] _ in
            Task { await self?.fetchMarkets() }
        }
        Task { await fetchMarkets() }
    }

    private func fetchMarkets() async {
        guard !watchedTickers.isEmpty else { return }

        // Kalshi API v2 - markets endpoint
        let tickerParam = watchedTickers.joined(separator: ",")
        guard let url = URL(string: "https://api.elections.kalshi.com/trade-api/v2/markets?tickers=\(tickerParam)") else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                reconnectAttempts += 1
                connectionState = .reconnecting(attempt: reconnectAttempts)
                if reconnectAttempts >= maxReconnectAttempts {
                    connectionState = .failed(URLError(.resourceUnavailable))
                }
                return
            }

            reconnectAttempts = 0
            connectionState = .connected

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let markets = json["markets"] as? [[String: Any]] else { return }

            for market in markets {
                guard let ticker = market["ticker"] as? String,
                      let title = market["title"] as? String,
                      let yesPrice = market["yes_bid"] as? Double ?? market["last_price"] as? Double
                else { continue }

                let previousPrice = previousPrices[ticker] ?? yesPrice
                let changePct = previousPrice > 0 ? ((yesPrice - previousPrice) / previousPrice) * 100 : 0
                previousPrices[ticker] = yesPrice

                guard abs(changePct) > 0.1 else { continue }

                let direction: Direction = changePct >= 0 ? .bullish : .bearish

                let signal = RawSignal(
                    sourceId: id,
                    symbol: title,
                    signalType: .predictionShift,
                    direction: direction,
                    value: yesPrice * 100,
                    changePercent: changePct,
                    message: nil,
                    timestamp: Date()
                )
                continuation?.yield(signal)
            }
        } catch {
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                connectionState = .reconnecting(attempt: reconnectAttempts)
            } else {
                connectionState = .failed(error)
            }
        }
    }
}
```

- [ ] **Step 5: Verify compilation of all adapters together**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Services/Adapters/MarketAdapter.swift Hoop/Services/Adapters/BinanceAdapter.swift Hoop/Services/Adapters/BybitAdapter.swift Hoop/Services/Adapters/PolymarketAdapter.swift Hoop/Services/Adapters/KalshiAdapter.swift`

- [ ] **Step 6: Commit**

```bash
git add Hoop/Services/Adapters/
git commit -m "feat: add Binance, Bybit, Polymarket, and Kalshi market adapters"
```

---

## Task 6: AlertEngine Service

**Files:**
- Create: `Hoop/Services/AlertEngine.swift`

Depends on TradingModels, MarketAdapter protocol, all adapters, and WebhookServer (Tasks 1, 4, 5).

- [ ] **Step 1: Create AlertEngine.swift**

```swift
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
```

- [ ] **Step 2: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Services/Adapters/MarketAdapter.swift Hoop/Services/Adapters/BinanceAdapter.swift Hoop/Services/Adapters/BybitAdapter.swift Hoop/Services/Adapters/PolymarketAdapter.swift Hoop/Services/Adapters/KalshiAdapter.swift Hoop/Services/WebhookServer.swift Hoop/Services/AlertEngine.swift`

- [ ] **Step 3: Commit**

```bash
git add Hoop/Services/AlertEngine.swift
git commit -m "feat: add AlertEngine with priority evaluation, queue, dedup, and active hours"
```

---

## Task 7: Alert Display Views

**Files:**
- Create: `Hoop/Views/AlertToastView.swift`
- Create: `Hoop/Views/AlertDetailView.swift`
- Create: `Hoop/Views/NotchAccentGlow.swift`

Pure SwiftUI views, depend on TradingModels (Task 1).

- [ ] **Step 1: Create NotchAccentGlow.swift**

```swift
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
```

- [ ] **Step 2: Create AlertToastView.swift**

```swift
// Hoop/Views/AlertToastView.swift
import SwiftUI

struct AlertToastView: View {
    let alert: TradingAlert
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Platform icon
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(alert.accentColor.color)

            // Direction arrow
            Image(systemName: alert.signal.direction == .bullish ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(alert.accentColor.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.signal.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(summaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let change = alert.signal.changePercent {
                Text(String(format: "%+.1f%%", change))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(alert.accentColor.color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onTapGesture { onDismiss() }
    }

    private var iconName: String {
        switch alert.signal.sourceId {
        case "binance", "bybit": return "chart.line.uptrend.xyaxis"
        case "polymarket", "kalshi": return "chart.pie"
        case "webhook": return "antenna.radiowaves.left.and.right"
        default: return "bell"
        }
    }

    private var summaryText: String {
        let price = String(format: "%.2f", alert.signal.value)
        switch alert.signal.signalType {
        case .priceAlert: return "$\(price)"
        case .predictionShift: return "\(price)% probability"
        case .tradingSignal: return alert.signal.message ?? "$\(price)"
        }
    }
}
```

- [ ] **Step 3: Create AlertDetailView.swift**

```swift
// Hoop/Views/AlertDetailView.swift
import SwiftUI

struct AlertDetailView: View {
    let alert: TradingAlert
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(alert.accentColor.color)

                Text(alert.signal.sourceId.capitalized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Main content
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.signal.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(2)

                    Text(detailText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceText)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))

                    if let change = alert.signal.changePercent {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(alert.accentColor.color)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)

                Button(action: onSnooze) {
                    Label("Snooze", systemImage: "bell.slash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onOpenInBrowser) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var iconName: String {
        switch alert.signal.sourceId {
        case "binance", "bybit": return "chart.line.uptrend.xyaxis"
        case "polymarket", "kalshi": return "chart.pie"
        case "webhook": return "antenna.radiowaves.left.and.right"
        default: return "bell"
        }
    }

    private var priceText: String {
        switch alert.signal.signalType {
        case .predictionShift: return String(format: "%.0f%%", alert.signal.value)
        default: return String(format: "$%.2f", alert.signal.value)
        }
    }

    private var detailText: String {
        switch alert.signal.signalType {
        case .priceAlert: return "Price Alert"
        case .predictionShift: return "Prediction Market"
        case .tradingSignal: return alert.signal.message ?? "Trading Signal"
        }
    }
}
```

- [ ] **Step 4: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Views/NotchAccentGlow.swift Hoop/Views/AlertToastView.swift Hoop/Views/AlertDetailView.swift`

- [ ] **Step 5: Commit**

```bash
git add Hoop/Views/AlertToastView.swift Hoop/Views/AlertDetailView.swift Hoop/Views/NotchAccentGlow.swift
git commit -m "feat: add alert toast, detail, and accent glow views"
```

---

## Task 8: EyeScanUnlockView

**Files:**
- Create: `Hoop/Views/EyeScanUnlockView.swift`

Depends on SecurityGate (Task 3) for auth phase enum.

- [ ] **Step 1: Create EyeScanUnlockView.swift**

```swift
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
        GeometryReader { geo in
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
```

- [ ] **Step 2: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Services/SecurityGate.swift Hoop/Views/EyeScanUnlockView.swift`

- [ ] **Step 3: Commit**

```bash
git add Hoop/Views/EyeScanUnlockView.swift
git commit -m "feat: add EyeScanUnlockView with iris animation and PIN entry"
```

---

## Task 9: TradingAlertsWidget

**Files:**
- Create: `Hoop/Views/Widgets/TradingAlertsWidget.swift`

Depends on WidgetProtocol (existing), TradingModels, AlertEngine (Tasks 1, 6).

- [ ] **Step 1: Create TradingAlertsWidget.swift**

```swift
// Hoop/Views/Widgets/TradingAlertsWidget.swift
import SwiftUI

struct TradingAlertsWidgetView: View {
    let alertEngine: AlertEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                Text("Trading Alerts")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if alertEngine.hasUnreadAlerts {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                }
            }

            if alertEngine.recentAlerts.isEmpty {
                Text("No recent alerts")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(alertEngine.recentAlerts.prefix(20)) { alert in
                            alertRow(alert)
                        }
                    }
                }
            }
        }
        .onAppear { alertEngine.markAlertsRead() }
    }

    private func alertRow(_ alert: TradingAlert) -> some View {
        HStack(spacing: 8) {
            // Direction indicator
            Image(systemName: alert.signal.direction == .bullish ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(alert.accentColor.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(alert.signal.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(alert.signal.sourceId.capitalized)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if let change = alert.signal.changePercent {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(alert.accentColor.color)
                }
                Text(alert.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct TradingAlertsWidget: NotchWidget {
    let id = "tradingAlerts"
    let name = "Trading Alerts"
    let icon = "chart.line.uptrend.xyaxis"
    let size: WidgetSize = .large

    let alertEngine: AlertEngine

    @MainActor
    func makeBody() -> AnyView {
        AnyView(TradingAlertsWidgetView(alertEngine: alertEngine))
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 Hoop/Models/TradingModels.swift Hoop/Models/WidgetProtocol.swift Hoop/Services/Adapters/MarketAdapter.swift Hoop/Services/Adapters/BinanceAdapter.swift Hoop/Services/Adapters/BybitAdapter.swift Hoop/Services/Adapters/PolymarketAdapter.swift Hoop/Services/Adapters/KalshiAdapter.swift Hoop/Services/WebhookServer.swift Hoop/Services/AlertEngine.swift Hoop/Views/Widgets/TradingAlertsWidget.swift`

- [ ] **Step 3: Commit**

```bash
git add Hoop/Views/Widgets/TradingAlertsWidget.swift
git commit -m "feat: add TradingAlertsWidget for alert feed in widget drawer"
```

---

## Task 10: Settings Updates (Markets Tab + Security Section)

**Files:**
- Modify: `Hoop/Views/SettingsView.swift`

Depends on AlertEngine (Task 6), SecurityGate (Task 3).

- [ ] **Step 1: Add Markets tab to SettingsView TabView**

In `Hoop/Views/SettingsView.swift`, add a new tab in the TabView (after the existing DropActions tab, before About):

```swift
MarketsSettingsTab(alertEngine: alertEngine)
    .tabItem {
        Label("Markets", systemImage: "chart.line.uptrend.xyaxis")
    }
    .tag(7)
```

Also add the `alertEngine: AlertEngine` and `securityGate: SecurityGate` parameters to SettingsView's properties.

- [ ] **Step 2: Create MarketsSettingsTab struct**

Add at the bottom of SettingsView.swift (or as a separate section):

```swift
struct MarketsSettingsTab: View {
    let alertEngine: AlertEngine

    var body: some View {
        Form {
            // Platform toggles
            Section("Platforms") {
                ForEach(["binance", "bybit", "polymarket", "kalshi"], id: \.self) { platformId in
                    PlatformConfigRow(alertEngine: alertEngine, platformId: platformId)
                }
            }

            // Webhook
            Section("Webhook (TradingView)") {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("9876", value: .init(
                        get: { Int(UserDefaults.standard.object(forKey: "webhookPort") as? Int ?? 9876) },
                        set: { UserDefaults.standard.set($0, forKey: "webhookPort") }
                    ), format: .number)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Bearer Token (optional)")
                    Spacer()
                    TextField("", text: .init(
                        get: { UserDefaults.standard.string(forKey: "webhookBearerToken") ?? "" },
                        set: { UserDefaults.standard.set($0, forKey: "webhookBearerToken") }
                    ))
                    .frame(width: 200)
                    .textFieldStyle(.roundedBorder)
                }

                Toggle("Enable Webhook Server", isOn: .init(
                    get: { UserDefaults.standard.bool(forKey: "webhookEnabled") },
                    set: { UserDefaults.standard.set($0, forKey: "webhookEnabled") }
                ))

                Button("Send Test Alert") {
                    alertEngine.webhookServer?.sendTestAlert()
                }
            }

            // Alert settings
            Section("Alert Behavior") {
                HStack {
                    Text("Dedup Window")
                    Spacer()
                    Text("\(Int(UserDefaults.standard.object(forKey: "alertDedupWindow") as? Double ?? 60))s")
                    Slider(value: .init(
                        get: { UserDefaults.standard.object(forKey: "alertDedupWindow") as? Double ?? 60 },
                        set: { UserDefaults.standard.set($0, forKey: "alertDedupWindow") }
                    ), in: 30...300, step: 30)
                    .frame(width: 150)
                }

                HStack {
                    Text("Toast Duration")
                    Spacer()
                    Text("\(Int(UserDefaults.standard.object(forKey: "alertDismissTimeout") as? Double ?? 4))s")
                    Slider(value: .init(
                        get: { UserDefaults.standard.object(forKey: "alertDismissTimeout") as? Double ?? 4 },
                        set: { UserDefaults.standard.set($0, forKey: "alertDismissTimeout") }
                    ), in: 2...10, step: 1)
                    .frame(width: 150)
                }

                HStack {
                    Text("Snooze Duration")
                    Spacer()
                    Text("\(Int((UserDefaults.standard.object(forKey: "alertSnoozeDuration") as? Double ?? 300) / 60))m")
                    Slider(value: .init(
                        get: { UserDefaults.standard.object(forKey: "alertSnoozeDuration") as? Double ?? 300 },
                        set: { UserDefaults.standard.set($0, forKey: "alertSnoozeDuration") }
                    ), in: 60...1800, step: 60)
                    .frame(width: 150)
                }

                Toggle("System notifications for high-priority alerts", isOn: .init(
                    get: { UserDefaults.standard.bool(forKey: "alertSystemNotifications") },
                    set: { UserDefaults.standard.set($0, forKey: "alertSystemNotifications") }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
    }
}

struct PlatformConfigRow: View {
    let alertEngine: AlertEngine
    let platformId: String

    @State private var config: PlatformConfig

    init(alertEngine: AlertEngine, platformId: String) {
        self.alertEngine = alertEngine
        self.platformId = platformId
        self._config = State(initialValue: alertEngine.config(for: platformId))
    }

    private var platformName: String {
        platformId.capitalized
    }

    var body: some View {
        DisclosureGroup {
            if platformId == "binance" || platformId == "bybit" {
                HStack {
                    Text("API Key")
                    Spacer()
                    SecureField("", text: Binding(
                        get: { config.apiKey ?? "" },
                        set: { config.apiKey = $0.isEmpty ? nil : $0; save() }
                    ))
                    .frame(width: 200)
                    .textFieldStyle(.roundedBorder)
                }
            }

            if platformId == "polymarket" || platformId == "kalshi" {
                HStack {
                    Text("Poll Interval")
                    Spacer()
                    Text("\(Int(config.pollIntervalSeconds))s")
                    Slider(value: $config.pollIntervalSeconds, in: 5...300, step: 5)
                        .frame(width: 150)
                        .onChange(of: config.pollIntervalSeconds) { _, _ in save() }
                }
            }

            HStack {
                Text("Active Hours")
                Spacer()
                Picker("From", selection: $config.activeHoursStart) {
                    ForEach(0..<24, id: \.self) { Text("\($0):00") }
                }.frame(width: 80).onChange(of: config.activeHoursStart) { _, _ in save() }
                Text("to")
                Picker("To", selection: $config.activeHoursEnd) {
                    ForEach(0..<25, id: \.self) { Text($0 == 24 ? "24:00" : "\($0):00") }
                }.frame(width: 80).onChange(of: config.activeHoursEnd) { _, _ in save() }
            }

            HStack {
                Text("High Alert Threshold")
                Spacer()
                Text("\(String(format: "%.0f", config.thresholdHigh))%")
                Slider(value: $config.thresholdHigh, in: 1...20, step: 1)
                    .frame(width: 150)
                    .onChange(of: config.thresholdHigh) { _, _ in save() }
            }
        } label: {
            HStack {
                Toggle(platformName, isOn: $config.isEnabled)
                    .onChange(of: config.isEnabled) { _, _ in save() }

                // Connection health indicator
                if config.isEnabled {
                    let state = alertEngine.connectionState(for: platformId)
                    Circle()
                        .fill(connectionColor(state))
                        .frame(width: 8, height: 8)
                        .help(connectionLabel(state))
                }
            }
        }
    }

    private func save() {
        alertEngine.updateConfig(for: platformId, config)
    }

    private func connectionColor(_ state: AdapterConnectionState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting, .reconnecting: return .yellow
        case .failed: return .red
        case .disconnected: return .gray
        }
    }

    private func connectionLabel(_ state: AdapterConnectionState) -> String {
        switch state {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting(let attempt): return "Reconnecting (attempt \(attempt))..."
        case .failed: return "Connection failed"
        case .disconnected: return "Disconnected"
        }
    }
}
```

- [ ] **Step 3: Add Security section to GeneralSettingsTab**

In `GeneralSettingsTab` (within SettingsView.swift), add a Security section at the bottom:

Add `securityGate: SecurityGate` and `widgetRegistry: WidgetRegistry` as parameters to `GeneralSettingsTab`. Add these `@State` properties and the Security section:

```swift
// Add to GeneralSettingsTab struct:
let securityGate: SecurityGate
let widgetRegistry: WidgetRegistry

@State private var showSetPIN = false
@State private var showChangePIN = false
@State private var pinInput = ""
@State private var currentPINInput = ""
@State private var newPINInput = ""

// Add this Section at the bottom of GeneralSettingsTab body Form:
Section("Security") {
    if securityGate.isPINConfigured {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundStyle(.green)
            Text("PIN is set")
            Spacer()
            Button("Change PIN") { showChangePIN = true }
        }
    } else {
        HStack {
            Image(systemName: "lock.open")
                .foregroundStyle(.secondary)
            Text("No PIN configured")
            Spacer()
            Button("Set PIN") { showSetPIN = true }
        }
    }

    if securityGate.isPINConfigured {
        ForEach(widgetRegistry.widgets, id: \.id) { widget in
            Toggle(widget.name, isOn: Binding(
                get: { securityGate.protectedWidgetIds.contains(widget.id) },
                set: { enabled in
                    var ids = securityGate.protectedWidgetIds
                    if enabled { ids.insert(widget.id) } else { ids.remove(widget.id) }
                    securityGate.protectedWidgetIds = ids
                }
            ))
        }

        Picker("Auto-lock after", selection: Binding(
            get: { UserDefaults.standard.object(forKey: "autoLockTimeout") as? Int ?? 5 },
            set: { UserDefaults.standard.set($0, forKey: "autoLockTimeout") }
        )) {
            Text("1 minute").tag(1)
            Text("5 minutes").tag(5)
            Text("15 minutes").tag(15)
            Text("30 minutes").tag(30)
            Text("Never").tag(0)
        }

        Toggle("Lock on display sleep", isOn: Binding(
            get: { UserDefaults.standard.object(forKey: "lockOnSleep") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "lockOnSleep") }
        ))
    }
}
.alert("Set PIN", isPresented: $showSetPIN) {
    SecureField("Enter 4-6 digit PIN", text: $pinInput)
    Button("Set") {
        if pinInput.count >= 4 && pinInput.count <= 6 {
            _ = securityGate.setupPIN(pinInput)
            pinInput = ""
        }
    }
    Button("Cancel", role: .cancel) { pinInput = "" }
}
.alert("Change PIN", isPresented: $showChangePIN) {
    SecureField("Current PIN", text: $currentPINInput)
    SecureField("New PIN (4-6 digits)", text: $newPINInput)
    Button("Change") {
        _ = securityGate.changePIN(currentPIN: currentPINInput, newPIN: newPINInput)
        currentPINInput = ""
        newPINInput = ""
    }
    Button("Cancel", role: .cancel) { currentPINInput = ""; newPINInput = "" }
}
```

- [ ] **Step 4: Address SettingsView service injection**

`SettingsView` is instantiated in `HoopApp.swift` inside a `Settings { }` scene with no parameters. To thread services from `AppDelegate`'s `NotchWindowManager` to the Settings scene, expose the window manager from AppDelegate and read it via `@NSApplicationDelegateAdaptor`:

In `HoopApp.swift`, change:
```swift
// Current: SettingsView()
// Change to:
@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

// In Settings scene:
SettingsView(
    alertEngine: appDelegate.windowManager.alertEngine,
    securityGate: appDelegate.windowManager.securityGate,
    widgetRegistry: appDelegate.windowManager.widgetRegistry
)
```

In `AppDelegate.swift`, make `windowManager` a non-private property so `HoopApp` can access it:
```swift
// Change: private var windowManager: NotchWindowManager?
// To:     var windowManager: NotchWindowManager!
```

- [ ] **Step 5: Verify compilation**

Run: `swiftc -typecheck` on modified SettingsView, HoopApp, and AppDelegate files together. Full `xcodebuild` verification is deferred to Task 14.

- [ ] **Step 5: Commit**

```bash
git add Hoop/Views/SettingsView.swift
git commit -m "feat: add Markets settings tab and Security section under General"
```

---

## Task 11: Wire Everything into NotchWindowManager

**Files:**
- Modify: `Hoop/Window/NotchWindowManager.swift`

This is the integration task -- connects all new services.

- [ ] **Step 1: Add new service properties**

At line ~28 in NotchWindowManager.swift (after `let airDropService = AirDropService()`), add:

```swift
let startupAnimator = StartupAnimator()
let alertEngine = AlertEngine()
let webhookServer = WebhookServer()
let securityGate = SecurityGate()
```

- [ ] **Step 2: Configure AlertEngine with adapters**

In `init()`, after the existing service setup (around line 68), add:

```swift
// Configure trading alert adapters
let adapters: [any MarketAdapter] = [
    BinanceAdapter(),
    BybitAdapter(),
    PolymarketAdapter(),
    KalshiAdapter()
]
alertEngine.configure(adapters: adapters, webhookServer: webhookServer)
```

- [ ] **Step 3: Start/stop new services**

In the `startObserving` section (around lines 69-78), add:

```swift
alertEngine.startObserving()
securityGate.startObserving()
```

In `stopObserving` / `deinit` section (around lines 86-96), add:

```swift
alertEngine.stopObserving()
securityGate.stopObserving()
```

- [ ] **Step 4: Register TradingAlertsWidget**

In `registerWidgets()` (around line 112-124), add:

```swift
widgetRegistry.register(TradingAlertsWidget(alertEngine: alertEngine))
```

- [ ] **Step 5: Wire alert and startup callbacks**

After `wireHUDCallbacks()` in init, add a new method call `wireAlertCallbacks()` and implement:

```swift
private func wireAlertCallbacks() {
    // Startup animation
    startupAnimator.onComplete = { [weak self] in
        // Startup done, normal idle takes over
    }

    // Alert engine
    alertEngine.onAlert = { [weak self] alert in
        guard let self else { return }
        // Respect phase precedence: don't interrupt tray or HUD
        for (id, entry) in self.windows {
            if entry.state.phase == .tray || entry.state.phase == .hud {
                // Alert is already queued in AlertEngine, will fire when phase clears
                return
            }
        }
        // Show alert on primary notch screen
        if let (id, entry) = self.windows.first(where: { $0.value.state.screenHasNotch }) {
            entry.state.previousPhaseBeforeAlert = entry.state.phase
            entry.state.activeAlert = alert
            entry.state.phase = .alert
            self.resizeFrame(id: id, forPhase: .alert, alertPriority: alert.priority)
        }
    }

    alertEngine.onAlertDismissed = { [weak self] in
        guard let self else { return }
        for (id, entry) in self.windows {
            if entry.state.phase == .alert {
                let previousPhase = entry.state.previousPhaseBeforeAlert ?? .idle
                entry.state.activeAlert = nil
                entry.state.previousPhaseBeforeAlert = nil
                entry.state.phase = previousPhase
                self.resizeFrame(id: id, forPhase: previousPhase, alertPriority: nil)
            }
        }
    }

    // Security
    securityGate.onLockStateChanged = { [weak self] in
        // Views auto-update via @Observable, no explicit action needed
    }
}
```

- [ ] **Step 6: Update createWindow to pass new services to NotchRootView**

In `createWindow()` (around line 235), update the NotchRootView constructor to include the new services:

```swift
// Add to NotchRootView init call:
// startupAnimator: startupAnimator,
// alertEngine: alertEngine,
// securityGate: securityGate,
```

- [ ] **Step 7: Start startup animation after window creation**

In `synchronizeWindows()` or after `createWindow()`, trigger:

```swift
// Only on primary notch screen
if state.screenHasNotch {
    startupAnimator.start()
}
```

- [ ] **Step 8: Add `.alert` handling to resizeFrame/repositionWindow**

Add `.alert` case to any switch statements over `Phase` in window sizing methods. Alert medium uses HUD frame (400x60pt), alert high uses expanded frame.

- [ ] **Step 9: Verify compilation**

Run: `xcodebuild build -project Hoop.xcodeproj -scheme Hoop 2>&1 | tail -30`

Fix any compilation errors.

- [ ] **Step 10: Commit**

```bash
git add Hoop/Window/NotchWindowManager.swift
git commit -m "feat: wire StartupAnimator, AlertEngine, SecurityGate into NotchWindowManager"
```

---

## Task 12: Update NotchRootView Render Chain

**Files:**
- Modify: `Hoop/Views/NotchRootView.swift`
- Modify: `Hoop/Views/Widgets/CollapsedIndicatorBar.swift`

- [ ] **Step 1: Add new service parameters to NotchRootView**

Add to the struct properties (after `let airDropService: AirDropService`):

```swift
let startupAnimator: StartupAnimator
let alertEngine: AlertEngine
let securityGate: SecurityGate
```

- [ ] **Step 2: Add phase-driven booleans and update isActive**

Add after the existing boolean helpers:

```swift
private var isAlert: Bool { state.phase == .alert }
private var isStartup: Bool { startupAnimator.phase != .done }
```

**Critical:** Update the existing `isActive` computed property to include `.alert`:

```swift
// Change from: isExpanded || isHUD || isTray
// To:
private var isActive: Bool { isExpanded || isHUD || isTray || isAlert }
```

This ensures the notch frame resizes correctly when an alert is showing.

- [ ] **Step 3: Update render priority chain**

In the `body` view builder, restructure the conditional chain to match the spec render priority. Insert before the existing tray check:

```swift
// 1. Startup animation (highest priority)
if isStartup {
    startupOverlay
}
// 2. Active call
else if callService.isCallActive {
    IncomingCallView(callService: callService)
}
// 3. Security gate (when trying to show protected content while locked)
// (handled within individual widget views)
// 4. Tray
else if isTray {
    // existing tray code...
}
// 5. HUD
else if isHUD {
    // existing HUD code...
}
// 6. Alert phase
else if isAlert, let alert = state.activeAlert {
    // Security gate: show redacted if trading alerts widget is protected and locked
    if securityGate.isProtected("tradingAlerts") && !securityGate.isUnlocked {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text("Trading Alert -- Unlock to view")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .onTapGesture { /* SecurityGate unlock is triggered on expand */ }
    } else if alert.priority == .high {
        AlertDetailView(
            alert: alert,
            onDismiss: { alertEngine.dismissCurrentAlert() },
            onSnooze: { alertEngine.snoozeCurrentAlert() },
            onOpenInBrowser: { openAlertInBrowser(alert) }
        )
    } else {
        AlertToastView(alert: alert, onDismiss: { alertEngine.dismissCurrentAlert() })
    }
}
// ... rest of existing chain
```

- [ ] **Step 4: Add startup overlay computed property**

```swift
// Add to struct properties:
@State private var cursorBlink = true
@State private var pulseScale: CGFloat = 1.0
@State private var pulseOpacity: Double = 0.6

@ViewBuilder
private var startupOverlay: some View {
    ZStack {
        // Typewriter phase
        if startupAnimator.phase == .typewriter {
            HStack(spacing: 0) {
                Text(startupAnimator.displayText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                if startupAnimator.showCursor {
                    Rectangle()
                        .fill(.primary)
                        .frame(width: 2, height: 16)
                        .opacity(cursorBlink ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                                cursorBlink.toggle()
                            }
                        }
                }
            }
        }

        // Pulse phase - radial glow expanding from notch
        if startupAnimator.phase == .pulse {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.themeMode == .liquidGlass ? Color.white.opacity(0.3) : Color.cyan.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .drawingGroup() // Safe: isolated animated content
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        pulseScale = 3.0
                        pulseOpacity = 0
                    }
                }

            Text("Hoop")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .opacity(1.0 - pulseOpacity) // Fade in as pulse fades
        }
    }
    .onTapGesture { startupAnimator.skip() }
}
```

- [ ] **Step 5: Apply accent glow modifier**

On the NotchShape or outer container, add the glow modifier:

```swift
.notchAccentGlow(
    accent: state.activeAlert?.accentColor,
    isActive: isAlert
)
```

- [ ] **Step 6: Add animation for alert phase**

In the animation modifiers section:

```swift
.animation(.spring(response: 0.3, dampingFraction: 0.85), value: isAlert)
```

- [ ] **Step 7: Update CollapsedIndicatorBar for trading dot**

In `Hoop/Views/Widgets/CollapsedIndicatorBar.swift`, add `alertEngine: AlertEngine` parameter and a trading dot indicator:

```swift
// Add property:
let alertEngine: AlertEngine

// In the left-side indicators (before or after PrivacyIndicatorView):
if alertEngine.hasUnreadAlerts {
    Circle()
        .fill(Color.orange)
        .frame(width: 6, height: 6)
        .transition(.scale.combined(with: .opacity))
}
```

- [ ] **Step 8: Verify compilation**

Run: `xcodebuild build -project Hoop.xcodeproj -scheme Hoop 2>&1 | tail -30`

- [ ] **Step 9: Commit**

```bash
git add Hoop/Views/NotchRootView.swift Hoop/Views/Widgets/CollapsedIndicatorBar.swift
git commit -m "feat: integrate startup animation, alert phase, and security gate into NotchRootView"
```

---

## Task 13: Update Xcode Project File

**Files:**
- Modify: `Hoop.xcodeproj/project.pbxproj`

Register all 16 new files. This task must be done carefully to avoid ID collisions.

- [ ] **Step 1: Check existing IDs to avoid collisions**

Run: `grep -o 'BB[0-9A-F]\{6\}' Hoop.xcodeproj/project.pbxproj | sort -u`

The next available IDs start after the highest used BB ID.

- [ ] **Step 2: Create the Adapters PBXGroup**

Need a new PBXGroup for `Services/Adapters/`. Generate a unique ID (e.g., `BB00003A`).

- [ ] **Step 3: Add PBXFileReference entries for all 16 new files**

Each file needs a unique 24-char hex ID. Use the BB0000xx pattern, starting after the last used ID. Example format:

```
BB00003B /* TradingModels.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TradingModels.swift; sourceTree = "<group>"; };
```

Generate IDs for all 16 files:
- TradingModels.swift
- StartupAnimator.swift
- AlertEngine.swift
- SecurityGate.swift
- WebhookServer.swift
- MarketAdapter.swift
- BinanceAdapter.swift
- BybitAdapter.swift
- PolymarketAdapter.swift
- KalshiAdapter.swift
- AlertToastView.swift
- AlertDetailView.swift
- NotchAccentGlow.swift
- EyeScanUnlockView.swift
- TradingAlertsWidget.swift

- [ ] **Step 4: Add PBXBuildFile entries**

Each file reference gets a corresponding build file entry. Example:

```
BB00004B /* TradingModels.swift in Sources */ = {isa = PBXBuildFile; fileRef = BB00003B /* TradingModels.swift */; };
```

- [ ] **Step 5: Add to PBXGroup children arrays**

- `TradingModels.swift` → Models group (AA000035)
- `StartupAnimator.swift`, `AlertEngine.swift`, `SecurityGate.swift`, `WebhookServer.swift` → Services group (AA000036)
- New Adapters PBXGroup → Services group (AA000036) as child group
- `MarketAdapter.swift`, `BinanceAdapter.swift`, `BybitAdapter.swift`, `PolymarketAdapter.swift`, `KalshiAdapter.swift` → Adapters group (BB00003A)
- `AlertToastView.swift`, `AlertDetailView.swift`, `NotchAccentGlow.swift`, `EyeScanUnlockView.swift` → Views group (AA000033)
- `TradingAlertsWidget.swift` → Widgets group (AA000037)

- [ ] **Step 6: Add to PBXSourcesBuildPhase**

Add all 16 build file IDs to the `files = (...)` array in `AA000041 /* Sources */`.

- [ ] **Step 7: Create the Adapters directory**

Run: `mkdir -p Hoop/Services/Adapters`

- [ ] **Step 8: Verify project integrity**

Run: `xcodebuild build -project Hoop.xcodeproj -scheme Hoop 2>&1 | tail -30`

If you see "project is damaged", check for ID collisions.

- [ ] **Step 9: Commit**

```bash
git add Hoop.xcodeproj/project.pbxproj
git commit -m "chore: register all 16 new files in Xcode project"
```

---

## Task 14: Full Integration Build & Smoke Test

**Files:** None new -- verification only.

- [ ] **Step 1: Full clean build**

Run: `xcodebuild clean build -project Hoop.xcodeproj -scheme Hoop 2>&1 | tail -40`

- [ ] **Step 2: Fix any compilation errors**

Address any type mismatches, missing parameters, or import issues.

- [ ] **Step 3: Verify all Phase switch statements handle `.alert`**

Run: `grep -n 'case .hud' Hoop/Window/NotchWindowManager.swift Hoop/Window/NotchPanel.swift Hoop/Views/NotchRootView.swift`

Every switch over Phase that handles `.hud` should also handle `.alert`.

- [ ] **Step 4: Verify NotchRootView constructor is updated everywhere**

Run: `grep -rn 'NotchRootView(' Hoop/`

Every call site must include the new `startupAnimator:`, `alertEngine:`, `securityGate:` parameters.

- [ ] **Step 5: Verify CollapsedIndicatorBar constructor is updated everywhere**

Run: `grep -rn 'CollapsedIndicatorBar(' Hoop/`

Every call site must include the new `alertEngine:` parameter.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat: complete NotchNook v2 expansion - startup animation, trading alerts, security gate"
```

---

## Dependency Graph

```
Task 1 (Models + Protocol + Phase) ─────┬──> Task 5 (Adapters) ──┬──> Task 6 (AlertEngine) ──> Task 9 (Widget)──┐
                                         ├──> Task 4 (WebhookServer)──┘                                          │
                                         └──> Task 7 (Alert Views) ──────────────────────────────────────────────┤
                                                                                                                  │
Task 2 (StartupAnimator) ───────────────────────────────────────────────────────────────────────────────────────>├──> Task 11 (Wire into Manager)
                                                                                                                  │       │
Task 3 (SecurityGate) ──> Task 8 (EyeScanUnlockView) ──────────────────────────────────────────────────────────>┤       │
                                                                                                                  │       v
                                                                                                                  ├──> Task 12 (NotchRootView)
                                                                                                                  │       │
                                                                                                                  ├──> Task 10 (Settings)
                                                                                                                  │       │
                                                                                                                  v       v
                                                                                                           Task 13 (pbxproj)
                                                                                                                  │
                                                                                                                  v
                                                                                                           Task 14 (Integration Build)
```

**Parallelizable waves:**
- **Wave 1:** Tasks 1, 2, 3 (all independent foundations)
- **Wave 2:** Tasks 4, 5, 7, 8 (depend on Wave 1, independent of each other)
- **Wave 3:** Tasks 6, 9 (Task 6 depends on Tasks 4+5; Task 9 depends on Task 6)
- **Wave 4:** Tasks 10, 11, 12 (integration, depend on Wave 3)
- **Wave 5:** Task 13 (pbxproj, after all files exist)
- **Wave 6:** Task 14 (final verification -- all `xcodebuild` verification deferred to here)
