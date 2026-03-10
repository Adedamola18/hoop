# Product Requirements Document
## macOS Notch Utility App — "NotchBar"

**Version:** 1.0
**Last Updated:** March 9, 2026
**Target Platform:** macOS 14.0+ (Sonoma and later)
**Tech Stack:** Swift 5.9+, SwiftUI, AppKit interop

---

## 1. Product Overview

### 1.1 Vision
A lightweight macOS utility that transforms the MacBook notch (or top-center screen area on non-notch Macs) into an interactive, expandable widget surface — bringing Dynamic Island-style functionality to macOS.

### 1.2 Problem Statement
The MacBook's camera notch creates ~200pt of visually dead space flanking the camera housing. macOS provides no native mechanism to use this area. Users lose menu bar real estate to the notch while gaining nothing in return.

### 1.3 Solution
An always-on overlay app that sits seamlessly around the notch, providing contextual information (now playing, calendar, battery), quick actions (file drop, AirDrop, shortcuts), and system HUD replacements (volume, brightness) — all activated by hover/clicking the notch area.

### 1.4 Target Users
- MacBook Pro/Air owners (M1–M4 era, with or without notch)
- Productivity-focused users who want quick-access utilities
- Users who dislike macOS's default volume/brightness HUD
- Designers/developers who value polished, pixel-perfect UI

---

## 2. App Architecture

### 2.1 High-Level Architecture

```
┌──────────────────────────────────────────────────────┐
│                    NotchBarApp                        │
│                 (LSUIElement Agent)                   │
│                                                      │
│  ┌────────────────────────────────────────────────┐  │
│  │              AppCoordinator                     │  │
│  │  - Lifecycle management                         │  │
│  │  - Permission orchestration                     │  │
│  │                                                 │  │
│  │  ┌──────────────────┐  ┌───────────────────┐   │  │
│  │  │ NotchWindowManager│  │ ServiceRegistry   │   │  │
│  │  │ (per-screen)      │  │                   │   │  │
│  │  │ - Window creation │  │ ┌───────────────┐ │   │  │
│  │  │ - Positioning     │  │ │ MediaService  │ │   │  │
│  │  │ - State machine   │  │ │ CalendarServ  │ │   │  │
│  │  │ - Hit testing     │  │ │ BatteryServ   │ │   │  │
│  │  └──────────┬────────┘  │ │ HUDService    │ │   │  │
│  │             │           │ │ FileShelfServ │ │   │  │
│  │  ┌──────────▼────────┐  │ │ AirDropServ   │ │   │  │
│  │  │ NotchHostingView  │  │ └───────────────┘ │   │  │
│  │  │ (NSHostingView)   │  └───────────────────┘   │  │
│  │  │                   │                          │  │
│  │  │ ┌───────────────┐ │  ┌────────────────────┐  │  │
│  │  │ │ NotchRootView │ │  │ SettingsWindow     │  │  │
│  │  │ │ (SwiftUI)     │ │  │ (SwiftUI Settings) │  │  │
│  │  │ └───────────────┘ │  └────────────────────┘  │  │
│  │  └───────────────────┘                          │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### 2.2 Module Breakdown

| Module | Responsibility | Framework Dependencies |
|--------|---------------|----------------------|
| **App Shell** | Agent app lifecycle, menu bar status item, settings | AppKit, SwiftUI |
| **NotchWindowManager** | Overlay window per screen | AppKit (NSPanel) |
| **NotchRootView** | SwiftUI view hierarchy, state-driven rendering | SwiftUI |
| **MediaService** | Now-playing data, playback controls | MediaRemote (private), MRNowPlaying |
| **CalendarService** | Calendar events, day browsing | EventKit |
| **BatteryService** | Battery state monitoring | IOKit |
| **HUDService** | Volume/brightness monitoring, native HUD suppression | CoreAudio, IOKit |
| **FileShelfService** | Drag-drop file references, thumbnails, Quick Look | AppKit, QuickLook |
| **AirDropService** | Sharing files via AirDrop | NSSharingService |
| **ScreenDetector** | Notch detection, multi-monitor handling, screen change observation | AppKit (NSScreen) |
| **Settings & Persistence** | User preferences, widget config, appearance options | SwiftData or UserDefaults |

---

## 3. Technical Specifications

### 3.1 App Lifecycle & Identity

**Info.plist configuration:**
- `LSUIElement = true` — No dock icon, no standard app window
- `LSBackgroundOnly = false` — Can present UI (the overlay)
- Minimum deployment target: macOS 14.0

**Entry point:** Standard SwiftUI `@main App` struct. On launch:
1. Initialize `AppCoordinator`
2. Create `NSStatusItem` in the system menu bar (gear icon for settings access)
3. Run `ScreenDetector` to enumerate displays
4. For each eligible screen, create a `NotchWindowManager` instance
5. Request necessary permissions (prompt once, gracefully degrade if denied)

### 3.2 The Overlay Window — NotchWindowManager

This is the core technical component. One instance per screen.

**Window creation spec:**

| Property | Value | Rationale |
|----------|-------|-----------|
| Type | `NSPanel` subclass | Panels can float without becoming main window; hide on deactivation can be overridden |
| `styleMask` | `[.borderless, .nonactivatingPanel, .fullSizeContentView]` | No chrome; clicking the notch doesn't steal focus from the user's current app |
| `level` | `.statusBar + 1` | Above menu bar and status items, below system alerts and Spotlight |
| `backgroundColor` | `.clear` | Transparent canvas |
| `isOpaque` | `false` | Required for transparency |
| `hasShadow` | `false` | No system shadow — blends with notch |
| `collectionBehavior` | `[.moveToActiveSpace, .fullScreenAuxiliary, .stationary, .canJoinAllSpaces]` | Visible on all Spaces and alongside fullscreen apps |
| `ignoresMouseEvents` | Dynamic | `true` when collapsed and idle; `false` when active/expanded |
| `hidesOnDeactivate` | `false` | Must remain visible when app is not focused |
| `canBecomeKey` | Override → `true` | Required for text input in widgets (e.g., notes) |
| `canBecomeMain` | Override → `false` | Should never be the main window |

**Content:** `NSHostingView(rootView: NotchRootView(viewModel: ...))` set as `contentView`.

### 3.3 Screen Detection & Notch Geometry

**ScreenDetector responsibilities:**

1. **Identify notch presence:**
   ```
   screen.safeAreaInsets.top > 0  →  has hardware notch
   ```

2. **Calculate notch rect:**
   - Notch center X = `screen.frame.midX`
   - Notch width ≈ inferred from known hardware models or measured as the gap between left and right safe areas. Approximate values:
     - 14" MBP: ~200pt wide, ~32pt tall
     - 16" MBP: ~200pt wide, ~32pt tall
     - M2 Air: ~200pt wide, ~32pt tall
   - Fallback: Use `safeAreaInsets.top` as height, default 180pt width

3. **Non-notch fallback:**
   - Place a virtual "pill" notch at top-center of the screen
   - Width: 180pt, Height: 32pt
   - Position Y: at the menu bar bottom edge

4. **Multi-monitor:**
   - Listen for `NSApplication.didChangeScreenParametersNotification`
   - Re-enumerate screens on change; create/destroy NotchWindowManager instances as needed
   - Only show the full notch UI on screens that have a notch; show a minimal "handler" on external displays (configurable)

### 3.4 Window Positioning Algorithm

```
Given:
  screen: NSScreen
  notchWidth: CGFloat  (collapsed width matching hardware notch)
  notchHeight: CGFloat (from safeAreaInsets.top)
  expandedWidth: CGFloat (user-configurable, default ~600pt)
  expandedHeight: CGFloat (dynamic based on visible widgets)

Collapsed frame:
  x = screen.frame.midX - (notchWidth / 2)
  y = screen.frame.maxY - notchHeight   // NSWindow coords: origin at bottom-left
  width = notchWidth
  height = notchHeight

Expanded frame:
  x = screen.frame.midX - (expandedWidth / 2)
  y = screen.frame.maxY - expandedHeight
  width = expandedWidth
  height = expandedHeight

Transition: animate frame change with spring timing
```

---

## 4. SwiftUI View Hierarchy

### 4.1 View Tree

```
NotchRootView
├── GeometryReader (tracks window size)
│
├── if state == .collapsed
│   └── CollapsedNotchView
│       ├── NotchShapeBackground (rounded rect, dark fill)
│       ├── [optional] MiniNowPlayingView (waveform + album art peek)
│       └── [optional] MiniIndicatorView (brief volume/brightness flash)
│
├── if state == .expanded
│   └── ExpandedNotchView
│       ├── NotchShapeBackground (larger rounded rect, vibrancy material)
│       ├── ScrollView(.horizontal)
│       │   ├── WidgetPanel: MediaPlayerWidget
│       │   ├── WidgetPanel: CalendarWidget
│       │   ├── WidgetPanel: ShortcutsWidget
│       │   └── WidgetPanel: MirrorWidget
│       └── TrayDropZone (bottom strip for file shelf)
│
├── if state == .tray
│   └── TrayView
│       ├── NotchShapeBackground
│       ├── FileGrid (dropped files with thumbnails)
│       └── AirDropButton
```

### 4.2 State Machine

```
        ┌─────────┐
        ┌───────►│  IDLE   │◄────────────┐
        │        │(hidden/ │              │
        │        │collapsed│              │
        │        └────┬────┘              │
        │             │                   │
        │     hover / click / drag        │
        │             │                   │
        │        ┌────▼────┐         mouse exit +
        │        │EXPANDING│          timeout
        │        │(animating)│            │
        │        └────┬────┘              │
        │             │                   │
        │      animation complete         │
        │             │                   │
        │        ┌────▼────┐              │
        │        │EXPANDED │──────────────┘
        │        │(interactive)│
        │        └────┬────┘
        │             │
        │        drag file in
        │             │
        │        ┌────▼────┐
        └────────│  TRAY   │
                 │(file shelf)│
                 └─────────┘

   volume / brightness key press
        │
   ┌────▼────┐
   │   HUD   │──── auto-dismiss (2s) ───► IDLE
   │(indicator)│
   └─────────┘
```

**State Model (Swift):**
```swift
@Observable
class NotchState {
    enum Phase { case idle, expanding, expanded, tray, hud }
    var phase: Phase = .idle
    var hudType: HUDType? = nil     // .volume, .brightness, .keyboardBrightness
    var hudValue: Double = 0
    var dragActive: Bool = false
}
```

### 4.3 The Notch Shape

The notch background shape is a custom `Shape` conforming to SwiftUI's `Shape` protocol. It draws:

- A rounded rectangle whose top edge has a **concave cutout** matching the hardware notch profile (two inward curves flanking the camera area)
- In collapsed state, this matches the hardware notch dimensions exactly — the dark fill makes it invisible against the dark notch + menu bar
- In expanded state, the shape grows outward and downward, with the concave top edge expanding smoothly via animation
- On non-notch Macs, the shape is a simple **capsule** (fully rounded rectangle) since there's no hardware cutout to blend with.

### 4.4 Background Material

Two approaches (user-configurable):

1. **Opaque dark:** `Color.black` background — seamlessly blends with hardware notch and dark menu bar. Best for collapsed state.
2. **Vibrancy / blur:** Use an AppKit `NSVisualEffectView` bridged into SwiftUI for the expanded state. Material: `.hudWindow` or `.menu`. Blending: `.behindWindow`. This gives the frosted glass look matching macOS system UI.

The transition between opaque-dark (collapsed) and vibrancy (expanded) is animated.

---

## 5. Feature Specifications

### 5.1 Media Player Widget

**Data source:** MediaRemote private framework

**Capabilities:**
- Display: album art, track title, artist name, playback progress bar
- Controls: play/pause, next, previous (via `MRMediaRemoteSendCommand`)
- Live activity: when collapsed, show a small waveform animation and album art snippet flanking the notch
- Gesture: two-finger horizontal swipe inside notch area = skip track
- App detection: show the source app icon (Spotify, Apple Music, browser, etc.)

**Fallback:** If MediaRemote is unavailable (API changes), fall back to `MPNowPlayingInfoCenter` observation, which is public but less comprehensive.

**Privacy:** No special permissions required (MediaRemote reads system-level now-playing data).

### 5.2 Calendar Widget

**Data source:** EventKit (`EKEventStore`)

**Capabilities:**
- Show today's date and upcoming events (next 24h)
- Horizontal swipe to browse adjacent days
- Tap an event to open it in Calendar.app (`NSWorkspace.open(url:)`)
- Color-coded by calendar source

**Permissions required:** Calendar access (requested on first widget enable)

### 5.3 File Shelf (Tray)

**Capabilities:**
- Drag files onto the notch → they appear in a grid inside the tray view
- Files stored as URL references in a temp array (not copied, just bookmarked)
- Tap a file thumbnail to Quick Look preview (`QLPreviewPanel`)
- Drag files out of the tray to any app/Finder window
- AirDrop button: select files → invoke `NSSharingService(named: .sendViaAirDrop)`
- Configurable auto-clear (on app quit, after X hours, or manual)
- Persistence option: save file bookmarks to disk for cross-session shelf (using security-scoped bookmarks)

**Permissions required:** None for basic drag-drop; Full Disk Access for security-scoped bookmarks if persisting across sessions.

### 5.4 System HUD Replacement

**Capabilities:**
- Replace native volume overlay with a slim slider rendered inside the notch
- Replace native brightness overlay with a matching slider
- Optionally replace keyboard brightness overlay
- Animated appearance: notch briefly expands to show slider, auto-dismisses after 2 seconds of inactivity
- Interactive: user can grab the slider to adjust further

**Implementation approach:**
- Monitor volume changes via `CoreAudio` (`AudioObjectAddPropertyListener` on default output device)
- Monitor brightness via `CoreDisplay` / `IOKit` display services
- Suppress native HUD: use `NSEvent.addGlobalMonitorForEvents(matching: .systemDefined)` to detect OSD trigger keys, then race to display the custom HUD. Alternatively, use the private `OSDUIHelper` framework to suppress (fragile, may break between OS versions).

**Permissions required:** Accessibility (for global event monitoring)

### 5.5 Mirror (Webcam Preview)

**Capabilities:**
- One-click activation of the built-in webcam
- Live preview displayed in a widget panel
- Mirror/flip toggle

**Implementation:** `AVCaptureSession` with `AVCaptureVideoPreviewLayer` bridged into SwiftUI.

**Permissions required:** Camera access

### 5.6 Shortcuts Widget

**Capabilities:**
- Display a configurable grid of Shortcuts the user has selected
- Tap to run a shortcut
- Show running state / result briefly

**Implementation:** Run shortcuts via URL scheme `shortcuts://run-shortcut?name=<encoded_name>` or via `WFWorkflowRunRequest` if using SPI.

---

## 6. Interaction Design Spec

### 6.1 Activation Triggers (User-Configurable)

| Trigger | Behavior | Default |
|---------|----------|---------|
| **Hover** | Expand after cursor dwells inside notch area for 200ms | ON |
| **Click** | Expand on single click inside notch area | OFF |
| **Force click** | Expand on force/deep press | OFF |
| **Keyboard shortcut** | Global hotkey to toggle (e.g., `⌥ + N`) | OFF |

### 6.2 Dismissal

- Mouse exits the expanded area → start 300ms grace timer → collapse with spring animation
- Click outside → immediate collapse
- Press `Escape` → immediate collapse
- Switch to another Space → collapse

### 6.3 Gestures (Inside Expanded Notch)

| Gesture | Action |
|---------|--------|
| Horizontal swipe (2-finger) | Skip media track / browse calendar days |
| Scroll (2-finger vertical) | Scroll widget content if overflowing |
| Drag file in | Switch to tray view, show drop zone |
| Drag file out | Drag from shelf to any destination |
| Click widget header | Switch between widget panels |

### 6.4 HUD Interrupts

When a volume/brightness key is pressed:
1. If notch is collapsed → briefly expand to show HUD slider → auto-dismiss
2. If notch is expanded → overlay HUD slider on top of current content → auto-dismiss, then return to expanded view
3. HUD takes priority over all other states

---

## 7. Permissions Strategy

| Permission | Required For | When Requested | Graceful Degradation |
|-----------|-------------|----------------|---------------------|
| **Accessibility** | Global mouse monitoring, HUD interception | First launch | No hover-to-expand; click-only activation. No HUD replacement. |
| **Calendar** | Calendar widget | When user enables calendar widget | Widget shows "Grant access" button instead of events |
| **Camera** | Mirror widget | When user enables mirror widget | Widget shows "Grant access" button |
| **Screen Recording** | (Optional) Window-level info for context awareness | Not requested in v1.0 | N/A |
| **Notifications** | (Future) Notification relay | v2.0 | N/A |

**Philosophy:** Request permissions lazily (only when the feature is first activated), not all at once on launch. Clearly explain why each permission is needed with a pre-prompt alert before triggering the system dialog.

---

## 8. Settings & Customization

Accessible via the menu bar status item (gear icon) → opens a SwiftUI `Settings` scene.

### 8.1 General
- Launch at login (toggle, uses `SMAppService`)
- Activation trigger (hover / click / hotkey)
- Hover delay (slider, 100ms–500ms)
- Show on: notch displays only / all displays / specific displays

### 8.2 Appearance
- Expanded width (slider, 400pt–800pt)
- Corner radius (auto-match notch / custom)
- Background style: opaque dark / vibrancy / custom color
- Padding between widgets (slider)
- Animation speed (normal / fast / instant)

### 8.3 Widgets
- Enable/disable individual widgets
- Reorder widgets (drag-and-drop list)
- Per-widget settings (e.g., which calendars to show, which shortcuts to display)

### 8.4 HUD
- Enable/disable HUD replacement
- HUD style: slim bar / iOS-style slider / circular dial
- Auto-dismiss timeout (slider, 1s–5s)

### 8.5 Tray
- Auto-clear behavior: never / on quit / after N hours
- Max files in tray (slider, 5–50)
- Show file size labels (toggle)

---

## 9. Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Idle CPU** | < 0.5% | When collapsed, no media playing |
| **Active CPU** | < 3% | When expanded with all widgets visible |
| **Memory** | < 50 MB | Typical usage |
| **Animation FPS** | 60fps | Expand/collapse transitions |
| **Launch time** | < 1s to visible | From process start to notch overlay rendered |
| **Battery impact** | Negligible | Should not appear in Battery settings as significant energy consumer |

### 9.1 Optimization Strategies
- Use `TimelineView` sparingly — only for the media waveform animation, and only when media is actively playing
- Debounce `NSScreen` change notifications (coalesce within 500ms)
- Lazy-load widget views; don't instantiate calendar/mirror until first expansion
- Use `drawingGroup()` on complex animated views to flatten into Metal render pass
- Avoid `onAppear`/`onDisappear` thrashing by keeping the view hierarchy mounted but visibility-toggled

---

## 10. Build Phases & Milestones

### Phase 1 — Foundation (Weeks 1–3)
- [ ] Project setup: SwiftUI App, LSUIElement agent, menu bar status item
- [ ] ScreenDetector: notch detection, geometry calculation
- [ ] NotchWindowManager: borderless NSPanel creation, positioning, transparency
- [ ] NotchRootView: basic collapsed/expanded state with spring animation
- [ ] NotchShape: custom Shape that blends with hardware notch
- [ ] Mouse tracking: NSTrackingArea + global monitor for hover activation
- [ ] Basic expand/collapse on hover with proper dismissal
- **Deliverable:** An empty notch overlay that expands/collapses smoothly on hover

### Phase 2 — Core Widgets (Weeks 4–6)
- [ ] Widget plugin protocol and container system
- [ ] MediaService: MediaRemote integration, now playing data
- [ ] MediaPlayerWidget: album art, title, controls, progress
- [ ] Collapsed live activity: waveform animation when music plays
- [ ] CalendarService + CalendarWidget: today's events, swipe to browse
- [ ] Horizontal scroll between widget panels
- **Deliverable:** Working media + calendar widgets inside the expanding notch

### Phase 3 — File Shelf & HUD (Weeks 7–9)
- [ ] FileShelfService: drag-in, drag-out, thumbnails, Quick Look
- [ ] AirDrop integration via NSSharingService
- [ ] TrayView: file grid with drop zone
- [ ] HUDService: volume/brightness monitoring
- [ ] HUDOverlayView: slider rendering, auto-dismiss
- [ ] Native HUD suppression (best-effort, graceful fallback)
- **Deliverable:** Full tray functionality + system HUD replacement

### Phase 4 — Polish & Settings (Weeks 10–12)
- [ ] Settings window: all customization options
- [ ] Launch-at-login via SMAppService
- [ ] Multi-monitor support: per-screen instances, external display handler mode
- [ ] Non-notch Mac support: virtual pill notch
- [ ] Mirror widget (AVCaptureSession)
- [ ] Shortcuts widget
- [ ] Performance profiling and optimization pass
- [ ] Accessibility audit (VoiceOver labels, keyboard navigation)
- **Deliverable:** Feature-complete v1.0

### Phase 5 — Testing & Release (Weeks 13–14)
- [ ] Beta testing across hardware: 14" MBP, 16" MBP, M2 Air, non-notch Intel Mac
- [ ] macOS version testing: Sonoma, Sequoia
- [ ] Edge cases: clamshell mode, display hotplug, login screen behavior
- [ ] Memory leak profiling (Instruments)
- [ ] Final polish pass on animations and timing
- **Deliverable:** v1.0 release

---

## 11. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| MediaRemote API breaks in future macOS | High | High | Abstract behind a service protocol; maintain fallback to `MPNowPlayingInfoCenter`; monitor macOS betas actively |
| Native HUD suppression unreliable | High | Medium | Make HUD replacement opt-in; show custom HUD alongside native if suppression fails |
| Apple introduces native Dynamic Island for Mac | Medium | High | Differentiate with deeper customization, widget ecosystem, and file shelf features Apple won't ship |
| Accessibility permission denied by user | Medium | Medium | Fall back to click-only activation; clearly communicate reduced functionality |
| Window level conflicts with other overlay apps (Bartender, Rectangle, etc.) | Medium | Low | Make window level configurable; test with popular utility apps |
| App Store rejection (private API usage) | High | Medium | Distribute outside App Store (direct download + Setapp); if App Store is desired, remove MediaRemote dependency and use only public APIs |

---

## 12. Distribution Strategy

**Primary:** Direct download from website (DMG with notarized app)
**Secondary:** Setapp marketplace
**Not recommended for v1.0:** Mac App Store (due to MediaRemote private framework usage and HUD suppression techniques that would likely cause rejection)

If Mac App Store distribution is desired in the future, create a "Lite" version that uses only public APIs, sacrificing now-playing detection breadth and HUD replacement.

---

## 13. Future Roadmap (Post v1.0)

- **v1.1 — Pipelines:** User-defined drop actions (drop file → run shell script → return result). E.g., "drop image to compress," "drop file to upload and get link."
- **v1.2 — Notification Relay:** Show macOS notifications inside the notch as transient bubbles (requires Notification access).
- **v1.3 — Widget SDK:** Public Swift Package for third-party developers to create notch widgets.
- **v1.4 — Clipboard History:** Show recent clipboard items in a widget panel.
- **v1.5 — AI Integration:** Drop text/files into notch to invoke local LLM for summarization, translation, etc.
