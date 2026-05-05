# Hoop v2 Feature Expansion -- Design Spec

**Date:** 2026-03-18
**Status:** Approved
**Approach:** Platform Adapter Pattern (Approach B)

## Overview

Three subsystems designed together, built in parallel:
1. **Startup Animation** -- typewriter "Hoop" text + glow pulse ripple
2. **Trading Alerts Engine** -- live market data from crypto/prediction platforms
3. **Security Gate** -- PIN-based widget protection with cinematic eye-scan animation

---

## 1. Startup Animation System

### StartupAnimator Service

`@Observable` service owned by NotchWindowManager. Runs once per app launch.

**Phases:**
- `.typewriter` (1.5s) -- "Hoop" renders character by character at ~375ms/letter. Monospaced SF Pro, centered in collapsed notch. Blinking cursor after last character.
- `.pulse` (1s) -- radial gradient glow expands outward from notch edges. Theme accent color. Opacity fades 0.6 to 0. Uses `drawingGroup()` on pulse overlay only (safe).
- `.done` -- normal idle state takes over.

**Behavior:**
- `hasPlayedStartup` flag (not persisted -- plays every launch)
- Highest render priority in NotchRootView
- Skippable: any user interaction cancels animation, jumps to idle
- **Multi-monitor:** plays on the primary notch screen only. Other screens start in idle immediately.

**Files:**
- `Hoop/Services/StartupAnimator.swift`

---

## 2. Trading Alerts Engine

### 2.1 MarketAdapter Protocol

```swift
protocol MarketAdapter: AnyObject {
    var id: String { get }
    var name: String { get }
    var connectionType: ConnectionType { get }  
    // .websocket, .polling, .webhook
    var connectionState: AdapterConnectionState { get }
    func connect() async throws
    func disconnect()
    var signalStream: AsyncStream<RawSignal> { get }
}

enum ConnectionType { case websocket, polling, webhook }
enum AdapterConnectionState { case disconnected, connecting, connected, reconnecting, failed(Error) }
```

**Concurrency safety:** Adapters expose `AsyncStream<RawSignal>` instead of a mutable closure callback. This is inherently `Sendable`-safe across the network dispatch queues that WebSocket/REST adapters run on. `AlertEngine` consumes the streams on `@MainActor`.

**Reconnection policy:** All adapters must implement automatic reconnection with exponential backoff (1s, 2s, 4s, ... capped at 60s). After 10 consecutive failures, transition to `.failed` state and stop retrying. User can manually retry from Settings. Binance requires reconnection after 24h by design; adapters must handle this. Settings shows per-adapter connection health indicator (green dot = connected, yellow = reconnecting, red = failed).

### 2.2 Platform Adapters

| Adapter | Connection | Auth | Data |
|---------|-----------|------|------|
| BinanceAdapter | WebSocket | API key | Price tickers, threshold alerts |
| BybitAdapter | WebSocket | API key | Price tickers, threshold alerts |
| PolymarketAdapter | REST polling | None (public) | Probability shifts on watched markets |
| KalshiAdapter | REST polling | None (public) | Contract price movements |
| WebhookAdapter | Local HTTP server | None (localhost) | TradingView-compatible JSON POSTs |

**Polling rate limits:** Polymarket (~100 req/min) and Kalshi (~10 req/s) have public API rate limits. Adapters must batch requests (fetch all watched markets in a single call where the API supports it) and implement 429/rate-limit backoff. Minimum configurable poll interval respects these limits.

Each adapter normalizes output into `RawSignal`:

```swift
struct RawSignal {
    let sourceId: String        // adapter id
    let symbol: String          // "BTC/USDT", "Will X happen?"
    let signalType: SignalType  // .priceAlert, .predictionShift, .tradingSignal
    let direction: Direction    // .bullish, .bearish, .neutral
    let value: Double           // price or probability
    let changePercent: Double?  // % move that triggered
    let message: String?        // raw text (TradingView webhook body)
    let timestamp: Date
}

enum SignalType { case priceAlert, predictionShift, tradingSignal }
enum Direction { case bullish, bearish, neutral }
```

### 2.3 AlertEngine Service

`@Observable`, owned by NotchWindowManager. Central orchestrator.

**Responsibilities:**
1. **Adapter lifecycle** -- starts/stops adapters based on Settings toggles
2. **Priority evaluation** -- maps RawSignal to TradingAlert with priority:
   - **Low** (dot/badge): small moves below user threshold
   - **Medium** (toast, 3-5s): threshold crossings, moderate shifts
   - **High** (persistent expand): large moves (configurable %), high-confidence signals
3. **Active hours enforcement** -- per-platform start/end time. Outside hours, alerts silently dropped.
4. **Alert queue** -- medium alerts cycle one at a time. High-priority interrupts queue.
5. **Deduplication** -- suppresses duplicates within configurable window (default 60s). Dedup key: `(sourceId, symbol, signalType)`. Two signals with the same key within the window = dedup (only the first surfaces). Different symbols, sources, or signal types = not dedup.

```swift
struct TradingAlert: Identifiable {
    let id: UUID
    let signal: RawSignal
    let priority: AlertPriority     // .low, .medium, .high
    let accentColor: AlertAccent    // .bullish (green), .bearish (red), .prediction (amber)
    let timestamp: Date
    var state: AlertState           // .pending, .showing, .dismissed, .snoozed
}

enum AlertPriority: Comparable { case low, medium, high }
enum AlertAccent { case bullish, bearish, prediction }
enum AlertState { case pending, showing, dismissed, snoozed }
```

### 2.4 WebhookServer

- Uses Network framework `NWListener` for local HTTP server
- **Must bind to localhost only:** `NWEndpoint.hostPort(host: .ipv4(.loopback), port: ...)` to prevent LAN exposure
- Configurable port (default 9876)
- Accepts `POST /` with TradingView-compatible JSON body
- Parses into RawSignal, forwards to AlertEngine via `AsyncStream`
- Optional bearer token field in Settings for users who expose the webhook externally (e.g., via ngrok for cloud TradingView alerts)

### 2.5 Alert Display

**Low priority:** Pulsing colored dot in `CollapsedIndicatorBar` (left side, near privacy indicators). Tap expands to show recent alerts.

**Medium priority:** Notch transitions to `.alert` phase. Toast size (400x60pt). Icon + symbol + one-line summary. Colored accent glow on notch edge. Auto-dismiss 3-5s (configurable).

**High priority:** Same `.alert` phase, expanded size. Full details + dismiss/snooze/open-in-browser buttons. Accent glow persists. No auto-dismiss.

**Accent glow:** `NotchAccentGlow` view modifier on NotchShape. Soft outer glow via `shadow(color:radius:)` with opacity animation. Green (bullish), red (bearish), amber (prediction). Fade in 0.3s, fade out 0.5s.

**System notifications:** High-priority alerts optionally also send a macOS system notification via `UNUserNotificationCenter` (toggle in Settings, default off). This ensures visibility when apps are in full-screen mode and the notch panel is obscured.

### 2.6 Alert Phase Design

**Important:** The existing `Phase` enum is flat (`.idle`, `.expanding`, `.expanded`, `.tray`, `.hud`) and used with `==` pattern matching throughout `NotchPanel`, `NotchRootView`, and `NotchWindowManager`. Adding an associated value would break `Equatable` synthesis and require changes at 20+ call sites.

**Use the orthogonal overlay pattern** already established by `.hud`:
- Add a flat `.alert` case to the Phase enum (no associated value)
- Store alert metadata separately on NotchState: `var activeAlert: TradingAlert?` and `var previousPhaseBeforeAlert: Phase?`
- AlertEngine triggers phase change to `.alert`; NotchWindowManager saves previous phase
- On dismiss, restore `previousPhaseBeforeAlert`
- Alert priority determines frame size via `activeAlert?.priority`, not via the phase enum

Frame sizing (read from `activeAlert`):
- `.medium` priority -- HUD frame (400x60pt)
- `.high` priority -- expanded frame (configurable width x 200pt)

**Phase interaction precedence:**

| Current Phase | Alert Arrives | Behavior |
|--------------|---------------|----------|
| `.idle` | any | Transition to `.alert`, save `.idle` |
| `.expanding`/`.expanded` | any | Transition to `.alert`, save current phase |
| `.tray` | any | **Queue alert.** Tray is never interrupted (active drag operation). Alert fires when tray dismisses. |
| `.hud` | any | **Queue alert.** HUD auto-dismisses quickly. Alert fires after HUD dismiss. |
| `.alert` | higher priority | Interrupt current, show new. Previous alert re-queues. |
| `.alert` | same/lower | Queue. Shows after current alert dismisses. |

### 2.7 Settings: Markets Tab

- **Platform list:** toggle on/off, API key field (Binance/Bybit), poll interval slider (Polymarket/Kalshi: 5s-5min), connection health indicator per adapter
- **Webhook config:** port number, optional bearer token, test button (fires sample alert)
- **Active hours:** per-platform start/end time pickers
- **Alert thresholds:** per-platform sliders for low/medium/high boundaries (e.g., "High = price move > 5%")
- **General:** dedup window (30s-5min), snooze duration, queue behavior, system notification toggle for high-priority

**Files:**
- `Hoop/Models/TradingModels.swift`
- `Hoop/Services/AlertEngine.swift`
- `Hoop/Services/WebhookServer.swift`
- `Hoop/Services/Adapters/MarketAdapter.swift`
- `Hoop/Services/Adapters/BinanceAdapter.swift`
- `Hoop/Services/Adapters/BybitAdapter.swift`
- `Hoop/Services/Adapters/PolymarketAdapter.swift`
- `Hoop/Services/Adapters/KalshiAdapter.swift`
- `Hoop/Views/AlertToastView.swift`
- `Hoop/Views/AlertDetailView.swift`
- `Hoop/Views/NotchAccentGlow.swift`
- `Hoop/Views/Widgets/TradingAlertsWidget.swift`

---

## 3. Security Gate System

### 3.1 SecurityGate Service

`@Observable`, owned by NotchWindowManager.

**PIN Management:**
- PIN stored as **SHA-256 hash** in macOS Keychain (never plaintext)
- Keychain item: service `"com.hoops.hoop.securitygate"`, account `"pin-hash"`
- Access control: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (not synced to iCloud Keychain)
- 4-6 digit PIN, set in Settings
- Change requires entering current PIN first
- 5 failed attempts = 30-second lockout with countdown
- App sandbox is disabled (per Hoop.entitlements), so Keychain access is unrestricted

**Lock State:**
- `protectedWidgetIds: Set<String>` persisted to UserDefaults (IDs only, not PIN)
- Trading alerts widget locked by default on first setup
- `isUnlocked: Bool` -- session-level, resets to locked on:
  - App launch
  - Display sleep: observe `NSWorkspace.screensDidSleepNotification` (not system `willSleepNotification`)
  - Configurable auto-lock timeout (default 5 min)
  - Manual re-lock from menu bar

**Gating Logic:**
- NotchRootView checks `securityGate.isUnlocked` before showing protected widgets
- If locked: renders `EyeScanUnlockView` instead
- High-priority alerts from protected widgets show redacted: "Trading Alert -- Unlock to view" (accent glow still visible)

### 3.2 Eye-Scan Unlock Animation

`EyeScanUnlockView` -- cinematic PIN entry in the expanded notch frame.

**Visual sequence:**
1. **Iris Render (0.3s)** -- stylized iris graphic fades in. Concentric `Circle` strokes + radial gradient in theme accent. Breathing scale animation (0.98-1.02).
2. **Scan Lines (during entry)** -- horizontal semi-transparent lines sweep vertically across iris on loop. Slight blur.
3. **PIN Overlay** -- 4-6 dot indicators below iris. Dots fill as user types on keyboard. No number pad shown, no digits displayed.
4. **Success (0.5s)** -- iris pulses green, scan lines converge to center + flash. Radial glow burst. Crossfade to unlocked content.
5. **Failure (0.4s)** -- iris flashes red, horizontal shake (offset spring). Dots clear. Counter increments. After 5 fails: iris scales to 0, shows lockout countdown.

**Performance:**
- `drawingGroup()` on iris + scan lines only (safe, isolated content)
- Spring animations: 0.3s response, 0.7 damping
- Driven by `SecurityGate.authPhase`: `.idle`, `.scanning`, `.success`, `.failure`, `.lockedOut`

### 3.3 Settings: Security Section

- **Set/Change PIN** -- current PIN required to change
- **Protected Widgets** -- checklist toggle per widget
- **Auto-lock timeout** -- 1min / 5min / 15min / 30min / never
- **Lock on sleep** -- toggle (default on)

**Files:**
- `Hoop/Services/SecurityGate.swift`
- `Hoop/Views/EyeScanUnlockView.swift`

---

## 4. Integration

### Updated NotchRootView Render Priority

```
 1. Startup animation     (startupAnimator.phase != .done)
 2. Active call           (callService.isCallActive -- never masked by alerts)
 3. Security gate         (protected widget + locked -> EyeScanUnlockView)
 4. Tray phase            (file drop)
 5. HUD phase             (volume/brightness)
 6. Alert phase           (trading alerts - medium/high)
 7. AirDrop transfer      (collapsed indicator)
 8. Media widget          (expanded + hasActiveMedia)
 9. Collapsed media       (CollapsedMediaIndicator)
10. Collapsed indicators  (privacy + battery + trading dot)
11. Expanded default      (WidgetDrawerView)
```

### NotchWindowManager Additions

**New service properties:**
- `startupAnimator: StartupAnimator`
- `alertEngine: AlertEngine`
- `webhookServer: WebhookServer`
- `securityGate: SecurityGate`

**New callbacks:**
- `alertEngine.onAlert` -> triggers `.alert` phase transition (respects precedence table in 2.6)
- `securityGate.onLockStateChanged` -> triggers re-render of protected widgets
- `startupAnimator.onComplete` -> transitions to normal idle

### Settings Tab Organization

To prevent tab bar overcrowding (currently 7 tabs), group related tabs:
- Existing tabs remain as-is
- **Markets** tab -- platform toggles, API keys, poll intervals, active hours, thresholds, webhook config, connection health
- **Security** section -- nested under General tab (PIN setup, protected widgets, auto-lock, lock-on-sleep)

---

## 5. File Summary

### New Files (~16)

```
Hoop/
  Models/
    TradingModels.swift              -- RawSignal, TradingAlert, enums
  Services/
    StartupAnimator.swift            -- typewriter + pulse animation
    AlertEngine.swift                -- adapter orchestration, priority, queue
    SecurityGate.swift               -- PIN/Keychain, lock state, auth phases
    WebhookServer.swift              -- NWListener HTTP, TradingView parsing
    Adapters/
      MarketAdapter.swift            -- protocol definition
      BinanceAdapter.swift           -- WebSocket price streams
      BybitAdapter.swift             -- WebSocket price streams
      PolymarketAdapter.swift        -- REST polling public odds
      KalshiAdapter.swift            -- REST polling public contracts
  Views/
    EyeScanUnlockView.swift          -- iris animation + PIN entry
    AlertToastView.swift             -- medium-priority toast
    AlertDetailView.swift            -- high-priority expanded alert
    NotchAccentGlow.swift            -- glow view modifier
    Widgets/
      TradingAlertsWidget.swift      -- alert feed widget
```

### Modified Files

- `Hoop/Models/NotchState.swift` -- add flat `.alert` phase case + `activeAlert` / `previousPhaseBeforeAlert` properties
- `Hoop/Views/NotchRootView.swift` -- new render priority layers, accent glow integration
- `Hoop/Views/SettingsView.swift` -- Markets tab, Security section under General
- `Hoop/Views/Widgets/CollapsedIndicatorBar.swift` -- trading dot indicator
- `Hoop/Window/NotchWindowManager.swift` -- new services, callbacks, wiring, alert queue coordination
- `Hoop.xcodeproj/project.pbxproj` -- register all new files
