# PRD: Hoops — Full-Featured Dynamic Island for macOS

## Introduction

Hoops  transforms the MacBook notch (or a virtual pill on non-notch Macs) into a full-featured Dynamic Island — a persistent, context-aware overlay that provides media controls, system HUDs, live indicators, productivity widgets, file management, and deep customization. The goal is to make the notch the most useful area of the screen for daily workflows.

**Platform:** macOS 14.0+ (Sonoma), Swift 5.9+, SwiftUI + AppKit interop
**App type:** LSUIElement agent (no dock icon), NSPanel-based overlay
**Design direction:** User-configurable themes — solid dark, translucent dark, and Liquid Glass

## Goals

- Provide instant access to media playback controls for any playing app (Apple Music, Spotify, YouTube, etc.)
- Replace native macOS volume/brightness HUDs with a polished, customizable notch HUD
- Surface live system indicators (battery, camera/mic, Focus Mode, screen recording) without dedicated menu bar items
- Offer a widget drawer with productivity tools (calendar, notes, timer, clipboard history, shortcuts, etc.)
- Enable drag-and-drop file processing (compress, OCR, AirDrop, custom pipelines)
- Support notifications and live activities (incoming calls, timers, AirDrop transfers)
- Provide user-configurable themes and activation behaviors
- Work seamlessly on both notch and non-notch Macs

## User Stories

---

### Phase 1: Core Shell & Activation

#### US-001: Notch Detection & Window Placement
**Description:** As a user, I want the app to detect my MacBook's hardware notch and place an overlay precisely over it, so the experience feels native.

**Acceptance Criteria:**
- [ ] Detects notch via `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
- [ ] Places NSPanel overlay exactly over the hardware notch
- [ ] Falls back to a centered virtual pill (180pt wide) on non-notch Macs
- [ ] Handles multiple displays — one overlay per screen
- [ ] `swiftc -typecheck` passes

#### US-002: Expand/Collapse Animation
**Description:** As a user, I want the notch to smoothly expand into a panel when activated and collapse back, so it feels fluid and native.

**Acceptance Criteria:**
- [ ] Spring animation (response: 0.4, damping: 0.8) for expand/collapse
- [ ] Collapsed state matches hardware notch dimensions exactly
- [ ] Expanded state is configurable width (400-800pt, default 600pt) x 200pt height
- [ ] NotchShape with concave cutout animates smoothly between states
- [ ] `swiftc -typecheck` passes

#### US-003: Activation Triggers
**Description:** As a user, I want to choose how to activate the notch — hover, click, or keyboard shortcut — so it fits my workflow.

**Acceptance Criteria:**
- [ ] Hover activation with configurable dwell delay (100-500ms, default 200ms)
- [ ] Click-to-toggle activation mode
- [ ] Global keyboard shortcut (default Option+N) with customizable key combo
- [ ] Grace period (300ms) on mouse exit before collapsing
- [ ] Escape key and click-outside dismiss expanded panel
- [ ] Setting persists across launches via UserDefaults
- [ ] `swiftc -typecheck` passes

#### US-004: Theme System
**Description:** As a user, I want to choose between dark, translucent, and Liquid Glass themes so the notch matches my aesthetic preferences.

**Acceptance Criteria:**
- [ ] Solid dark theme: pure black background matching hardware notch
- [ ] Translucent dark theme: NSVisualEffectView with `.popover` material + dark tint overlay
- [ ] Liquid Glass theme: frosted glass with subtle color tinting from desktop wallpaper
- [ ] Theme selection in Settings > Appearance tab
- [ ] Theme persists via UserDefaults
- [ ] Smooth crossfade between themes when changed
- [ ] `swiftc -typecheck` passes

#### US-005: Non-Notch Mac Support
**Description:** As a user on a Mac without a notch, I want a virtual pill at the top of my screen that behaves identically to the notch overlay.

**Acceptance Criteria:**
- [ ] Virtual pill rendered at top-center of screen (180pt x menu bar height)
- [ ] Same expand/collapse behavior as notch overlay
- [ ] Same activation triggers work
- [ ] Adjustable pill size in Settings
- [ ] `swiftc -typecheck` passes

---

### Phase 2: Media & Playback

#### US-006: Now Playing Widget (Expanded)
**Description:** As a user, I want to see and control the currently playing track when I expand the notch, so I can manage music without switching apps.

**Acceptance Criteria:**
- [ ] Shows album art (100x100, rounded corners), track title, artist name
- [ ] Play/pause, next, previous buttons
- [ ] Progress bar showing elapsed/total time
- [ ] Supports Apple Music, Spotify, Tidal, YouTube, and any MediaRemote-compatible app
- [ ] Horizontal two-finger swipe on trackpad skips tracks
- [ ] Haptic feedback on track skip
- [ ] `swiftc -typecheck` passes

#### US-007: Collapsed Media Indicator
**Description:** As a user, I want to see at a glance that music is playing even when the notch is collapsed, via subtle indicators.

**Acceptance Criteria:**
- [ ] Album art peek (small circle) on the left side of collapsed notch
- [ ] Animated waveform bars on the right when playing (static when paused)
- [ ] Waveform uses TimelineView at 30fps only when playing (pauses for CPU savings)
- [ ] Metal-backed rendering via `drawingGroup()`
- [ ] `swiftc -typecheck` passes

#### US-008: Apple Music & Spotify Inline Previews
**Description:** As a user, I want richer previews for Apple Music and Spotify showing playlist context, up-next, and lyrics snippets.

**Acceptance Criteria:**
- [ ] Detects Apple Music / Spotify via bundle ID from MediaRemote client
- [ ] Shows "Up Next" track name below current track when available
- [ ] Displays playlist/album name as subtitle
- [ ] Optional lyrics line (if available from now playing info)
- [ ] Falls back gracefully to standard view for other apps
- [ ] `swiftc -typecheck` passes

#### US-009: YouTube & Video Background Playback Controls
**Description:** As a user watching YouTube or Netflix in a browser, I want media controls in the notch so I don't have to switch tabs.

**Acceptance Criteria:**
- [ ] Detects browser-based media via MediaRemote (Chrome, Safari, Firefox, Arc)
- [ ] Shows video title and source app icon
- [ ] Play/pause and skip controls work for browser media
- [ ] No special browser extension required (relies on MediaRemote)
- [ ] `swiftc -typecheck` passes

---

### Phase 3: System HUDs

#### US-010: Volume HUD
**Description:** As a user, I want volume changes to appear as a sleek slider in the notch instead of the default macOS floating HUD.

**Acceptance Criteria:**
- [ ] Monitors system volume via CoreAudio `AudioObjectAddPropertyListenerBlock`
- [ ] Displays horizontal slider with speaker icon and percentage
- [ ] Interactive drag to adjust volume
- [ ] Auto-dismiss after configurable timeout (1-5s, default 2s)
- [ ] Handles default output device changes (headphones, speakers, etc.)
- [ ] `swiftc -typecheck` passes

#### US-011: Brightness HUD
**Description:** As a user, I want brightness changes to appear in the notch with the same polish as the volume HUD.

**Acceptance Criteria:**
- [ ] Monitors display brightness via IOKit adaptive polling
- [ ] Displays horizontal slider with sun icon and percentage
- [ ] Interactive drag to adjust brightness
- [ ] Adaptive polling: 1s idle, 0.1s when HUD is active
- [ ] `swiftc -typecheck` passes

#### US-012: Native HUD Suppression
**Description:** As a user, I want the option to suppress the default macOS volume/brightness HUD so I don't see duplicate indicators.

**Acceptance Criteria:**
- [ ] CGEventTap intercepts NX_SYSDEFINED events for volume/brightness keys
- [ ] Returns nil from tap callback to suppress native OSD
- [ ] Graceful fallback if Accessibility permission not granted (both HUDs show)
- [ ] Toggle in Settings > HUD: "Replace system HUD" (default: on)
- [ ] Handles `.tapDisabledByTimeout` by re-enabling
- [ ] `swiftc -typecheck` passes

---

### Phase 4: System Indicators & Notifications

#### US-013: Battery & Charging Status Indicator
**Description:** As a user, I want to see battery percentage and charging state in the collapsed notch, so I can glance without checking the menu bar.

**Acceptance Criteria:**
- [ ] Shows battery percentage as small text on the collapsed notch (configurable position: left/right)
- [ ] Color-coded: green (>50%), yellow (20-50%), red (<20%)
- [ ] Charging bolt icon when plugged in
- [ ] Low battery warning animation at 10%
- [ ] Uses `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList` for battery data
- [ ] `swiftc -typecheck` passes

#### US-014: Privacy Indicators (Camera/Mic In Use)
**Description:** As a user, I want to see when my camera or microphone is in active use, displayed as a colored dot in the notch.

**Acceptance Criteria:**
- [ ] Green dot for camera active, orange dot for microphone active
- [ ] Matches macOS Sequoia privacy indicator colors
- [ ] Shows app name on hover/expand (e.g., "Zoom is using your camera")
- [ ] Uses CoreMediaIO / AVCaptureDevice for camera detection
- [ ] Uses AudioObjectGetPropertyData on input device for mic detection
- [ ] Dots appear at the edge of the collapsed notch
- [ ] `swiftc -typecheck` passes

#### US-015: Focus Mode Indicator
**Description:** As a user, I want to see my active Focus Mode name/icon in the collapsed notch so I know what mode I'm in.

**Acceptance Criteria:**
- [ ] Detects Focus Mode via DistributedNotificationCenter ("com.apple.doNotDisturb")
- [ ] Shows Focus Mode name (e.g., "Work", "Sleep") as small label
- [ ] Moon icon for Do Not Disturb
- [ ] Appears/disappears with animation when Focus Mode toggles
- [ ] `swiftc -typecheck` passes

#### US-016: Screen Recording Indicator
**Description:** As a user, I want a visible indicator when my screen is being recorded.

**Acceptance Criteria:**
- [ ] Red recording dot when screen capture is active
- [ ] Detects via `CGDisplayStreamCreate` or `SCC` framework presence check
- [ ] Pulses subtly to draw attention
- [ ] Shows recording app name on expand
- [ ] `swiftc -typecheck` passes

#### US-017: Incoming Call Display
**Description:** As a user, I want incoming FaceTime/phone calls to show as a live activity in the notch.

**Acceptance Criteria:**
- [ ] Detects incoming calls via CallKit or TelephonyUtilities private framework
- [ ] Shows caller name/number, accept/decline buttons
- [ ] Smooth expand animation from collapsed state
- [ ] Auto-dismisses if call is answered or declined elsewhere
- [ ] Falls back to notification-style display if call detection unavailable
- [ ] `swiftc -typecheck` passes

#### US-018: AirDrop Send/Receive Indicator
**Description:** As a user, I want to see AirDrop transfer progress in the notch.

**Acceptance Criteria:**
- [ ] Detects AirDrop activity via NSFileProviderService or Sharing framework
- [ ] Shows transfer progress bar, file name, and sender/receiver
- [ ] Accept/decline buttons for incoming transfers
- [ ] Auto-dismisses on completion
- [ ] `swiftc -typecheck` passes

---

### Phase 5: Widgets

#### US-019: Widget Drawer Architecture
**Description:** As a developer, I need a widget system that allows multiple widgets to be registered, arranged, and displayed in the expanded notch.

**Acceptance Criteria:**
- [ ] `Widget` protocol with `id`, `name`, `icon`, `view`, `size` (small/medium/large)
- [ ] `WidgetRegistry` manages available widgets and user-selected arrangement
- [ ] Expanded notch shows a scrollable grid/list of active widgets
- [ ] Widgets can be reordered in Settings
- [ ] Widget state persists across launches
- [ ] `swiftc -typecheck` passes

#### US-020: Calendar Widget
**Description:** As a user, I want to see my upcoming events in the notch so I know what's next without opening Calendar.

**Acceptance Criteria:**
- [ ] Shows next 3 upcoming events from EventKit (EKEventStore)
- [ ] Displays event title, time, and calendar color
- [ ] "In X minutes" relative time for imminent events
- [ ] Tapping an event opens Calendar.app to that event
- [ ] Requests calendar access on first use
- [ ] `swiftc -typecheck` passes

#### US-021: Notes Quick Capture Widget
**Description:** As a user, I want to quickly jot down a note from the notch without opening any app.

**Acceptance Criteria:**
- [ ] Text field for quick note entry
- [ ] Saves to a configurable destination: Apple Notes, text file, or clipboard
- [ ] Keyboard shortcut to focus the note field when expanded
- [ ] Shows last 3 recent notes as quick-recall list
- [ ] `swiftc -typecheck` passes

#### US-022: Timer / Stopwatch Widget
**Description:** As a user, I want a timer and stopwatch accessible from the notch for quick timing needs.

**Acceptance Criteria:**
- [ ] Countdown timer with preset buttons (1m, 5m, 10m, 25m) and custom entry
- [ ] Stopwatch with start/stop/lap/reset
- [ ] Timer completion notification sound + notch animation
- [ ] Running timer shows remaining time in collapsed notch
- [ ] `swiftc -typecheck` passes

#### US-023: Clipboard History Widget
**Description:** As a user, I want to access my recent clipboard items from the notch for quick paste.

**Acceptance Criteria:**
- [ ] Monitors `NSPasteboard.general` for changes via polling or notification
- [ ] Stores last 20 clipboard entries (text, images, file URLs)
- [ ] Click to re-copy an item to clipboard
- [ ] Search/filter clipboard history
- [ ] Pinnable items that persist until manually removed
- [ ] Privacy: option to exclude password manager entries
- [ ] `swiftc -typecheck` passes

#### US-024: Shortcuts Widget
**Description:** As a user, I want to trigger my favorite Shortcuts directly from the notch.

**Acceptance Criteria:**
- [ ] Lists user's Shortcuts from `/usr/bin/shortcuts list`
- [ ] Configurable favorites (pin up to 6 shortcuts)
- [ ] Run shortcut via `/usr/bin/shortcuts run "Name"`
- [ ] Shows running indicator and success/failure result
- [ ] `swiftc -typecheck` passes

#### US-025: Webcam Mirror Widget
**Description:** As a user, I want a quick webcam preview in the notch before joining a video call.

**Acceptance Criteria:**
- [ ] AVCaptureSession with default video device
- [ ] Shows live preview in a small rounded rect
- [ ] Camera indicator dot while active
- [ ] Auto-stops capture when widget is hidden/collapsed
- [ ] Permission request on first use
- [ ] `swiftc -typecheck` passes

#### US-026: Color Picker Widget
**Description:** As a user (designer/developer), I want a quick color picker accessible from the notch.

**Acceptance Criteria:**
- [ ] NSColorSampler integration for screen color picking
- [ ] Shows picked color swatch, hex value, RGB values
- [ ] Click to copy hex/RGB to clipboard
- [ ] History of last 10 picked colors
- [ ] `swiftc -typecheck` passes

#### US-027: Unit/Currency Converter Widget
**Description:** As a user, I want a quick converter for units and currency in the notch.

**Acceptance Criteria:**
- [ ] Category selector: length, weight, temperature, currency
- [ ] Input field with source unit, output field with target unit
- [ ] Swappable source/target
- [ ] Currency rates fetched from free API (with offline fallback to last fetched)
- [ ] `swiftc -typecheck` passes

#### US-028: System Stats Widget (CPU/Memory/Network/Disk)
**Description:** As a power user, I want to see system resource usage in the notch.

**Acceptance Criteria:**
- [ ] CPU usage percentage with mini bar chart
- [ ] Memory usage (used/total) with pressure indicator
- [ ] Network throughput (upload/download speed)
- [ ] Disk usage for boot volume
- [ ] GPU usage if available (via `host_processor_info` / Metal)
- [ ] Polling interval configurable (1s - 10s, default 2s)
- [ ] `swiftc -typecheck` passes

---

### Phase 6: File Management

#### US-029: Drag-and-Drop File Tray
**Description:** As a user, I want to drag files onto the notch to quickly process them (compress, OCR, run shortcuts).

**Acceptance Criteria:**
- [ ] NSPanel registers for `.fileURL` drag type
- [ ] Drag over notch expands into drop zone with pulsing indicator
- [ ] If single action matches file type, executes immediately
- [ ] If multiple actions match, shows selection UI
- [ ] Built-in actions: Compress Image, OCR Text Extraction
- [ ] Custom actions: Shortcuts, shell scripts, multi-step pipelines
- [ ] Progress indicator during processing, success/failure result
- [ ] `swiftc -typecheck` passes

#### US-030: Quick AirDrop from Notch
**Description:** As a user, I want to AirDrop files by dragging them to the notch and selecting a nearby device.

**Acceptance Criteria:**
- [ ] After file drop, show "AirDrop" as an action option
- [ ] Discovers nearby AirDrop devices via `NSFilePromiseReceiver` / SharingService
- [ ] Shows device list with icons
- [ ] Transfer progress shown in notch
- [ ] Uses `NSSharingService(named: .sendViaAirDrop)`
- [ ] `swiftc -typecheck` passes

---

### Phase 7: Customization & Settings

#### US-031: Settings Window
**Description:** As a user, I want a comprehensive settings window to configure all Hoop features.

**Acceptance Criteria:**
- [ ] Tabbed interface: General, Appearance, Media, HUD, Widgets, Drop Actions, Context Rules
- [ ] General: activation trigger, launch at login, expanded size
- [ ] Appearance: theme picker, transparency slider, corner radius
- [ ] Widgets: enable/disable individual widgets, reorder
- [ ] All settings persist via UserDefaults
- [ ] `swiftc -typecheck` passes

#### US-032: Gesture Controls
**Description:** As a user, I want to customize what gestures do on the notch (swipe, pinch, long press).

**Acceptance Criteria:**
- [ ] Horizontal swipe: configurable (skip track, switch widget, none)
- [ ] Vertical swipe down: configurable (expand, show widgets, none)
- [ ] Long press: configurable (show settings, show widget picker, none)
- [ ] Pinch: configurable (adjust volume, adjust brightness, none)
- [ ] Settings UI for gesture assignments
- [ ] `swiftc -typecheck` passes

#### US-033: Adjustable Size & Padding
**Description:** As a user, I want to control how large the expanded notch is and its padding from content.

**Acceptance Criteria:**
- [ ] Expanded width slider: 400-800pt (default 600pt)
- [ ] Expanded height slider: 150-400pt (default 200pt)
- [ ] Content padding slider: 8-32pt (default 16pt)
- [ ] Live preview of changes
- [ ] `swiftc -typecheck` passes

#### US-034: Context-Aware Widget Switching
**Description:** As a user, I want the notch to automatically show relevant widgets based on the frontmost app, time of day, or Focus Mode.

**Acceptance Criteria:**
- [ ] Frontmost app detection via NSWorkspace.didActivateApplicationNotification
- [ ] Media app detection shows media widget automatically
- [ ] Time-of-day profiles (morning/afternoon/evening) with widget assignments
- [ ] Focus Mode overrides (e.g., "Work" focus shows calendar + timer)
- [ ] Custom rules engine: condition (app/time/focus) -> widget assignment
- [ ] Rules evaluated in priority order, first match wins
- [ ] `swiftc -typecheck` passes

---

### Phase 8: Performance & Resilience

#### US-035: CPU & Memory Optimization
**Description:** As a user, I want Hoop to use minimal system resources even with multiple features active.

**Acceptance Criteria:**
- [ ] Idle CPU usage < 1% (no animations running)
- [ ] Animations use `drawingGroup()` for Metal-backed rendering
- [ ] Adaptive polling intervals (faster when active, slower when idle)
- [ ] Cache expensive lookups (NSWorkspace, UserDefaults JSON stores)
- [ ] TimelineView guarded by playing state (no animation frames when paused)
- [ ] `swiftc -typecheck` passes

#### US-036: Sleep/Wake & Display Hotplug Resilience
**Description:** As a user, I want Hoop to survive sleep/wake cycles and monitor connect/disconnect without glitches.

**Acceptance Criteria:**
- [ ] Listens for NSWorkspace.willSleepNotification / didWakeNotification
- [ ] Collapses all panels before sleep
- [ ] Re-syncs windows 1.5s after wake (lets screen params settle)
- [ ] Debounces rapid screen configuration changes (500ms)
- [ ] Correctly repositions windows after display arrangement changes
- [ ] No crashes on rapid connect/disconnect cycles
- [ ] `swiftc -typecheck` passes

---

## Functional Requirements

- FR-1: The app must run as an LSUIElement agent (no dock icon) with a MenuBarExtra
- FR-2: The overlay NSPanel must be `.statusBar + 1` level, `.canJoinAllSpaces`, `.stationary`, `.fullScreenAuxiliary`
- FR-3: The panel must not hide on deactivate (`hidesOnDeactivate = false`)
- FR-4: MediaRemote private framework must be loaded via dlopen/dlsym at runtime
- FR-5: All CoreAudio/IOKit callbacks must dispatch to main thread
- FR-6: Theme changes must apply immediately without restart
- FR-7: Widget protocol must support async loading for network-dependent widgets
- FR-8: Clipboard history must not store items from password managers (configurable exclusion list)
- FR-9: All file operations in the drop tray must be non-blocking (async/await)
- FR-10: System stats polling must be configurable and default to power-efficient intervals
- FR-11: CGEventTap for HUD suppression must handle Accessibility permission gracefully
- FR-12: The app must handle multiple displays independently (one overlay per screen)

## Non-Goals (Out of Scope)

- No iOS/iPadOS companion app
- No App Store distribution (direct download only, due to private framework usage)
- No plugin/extension SDK for third-party widget developers (v3 consideration)
- No touch bar integration
- No Apple Watch integration
- No notification filtering/management (just display)
- No window management features (tiling, snapping)

## Design Considerations

- **Design reference:** `design.pen` in project root contains the iCloud widget concept with the navy/slate palette (#0F1B2E to #070D16 background, #1C2333 to #151B28 panels, #5BADE4 accent blue)
- **Typography:** System font (SF Pro) for native feel; weight 500-600 for labels, 400 for body
- **Iconography:** SF Symbols throughout for consistency
- **Animation:** Spring animations for all expand/collapse; `.easeInOut` for opacity transitions
- **Collapsed indicators:** Must fit within notch dimensions without overlapping menu bar items
- **Expanded layout:** Content positioned below the notch cutout area with proper padding

## Technical Considerations

- MediaRemote framework is private — no App Store distribution possible
- CoreAudio volume monitoring requires AudioToolbox import
- IOKit brightness has no notification API — requires polling
- CGEventTap requires Accessibility permission
- EventKit requires calendar access permission
- AVCaptureSession requires camera permission
- `swiftc -typecheck` is the build verification method (no Xcode.app build required)
- New Swift files must be added to `project.pbxproj` (PBXFileReference + PBXBuildFile + PBXGroup + PBXSourcesBuildPhase)
- Existing services: MediaService, HUDService, ContextService, DropActionService

## Success Metrics

- Idle CPU usage under 1%
- Expand/collapse animation completes in under 500ms
- Volume/brightness HUD appears within 50ms of key press
- All 36 user stories pass `swiftc -typecheck`
- No crashes during 24-hour continuous use test
- User can configure all features without editing files

## Open Questions

- Should the widget drawer use a horizontal carousel or vertical scroll layout?
- Should clipboard history sync across devices via iCloud?
- Should we support custom CSS/SwiftUI theming beyond the 3 built-in themes?
- Should AirDrop detection use public or private frameworks?
- Maximum number of simultaneous collapsed indicators before overflow?
