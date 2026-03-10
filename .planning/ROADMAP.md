# Roadmap: Hoops

## Overview

Hoops delivers a polished macOS notch overlay in seven phases: first the app shell and window positioning, then the core expand/collapse interaction, followed by the two main widgets (media player and HUD replacement), context-aware switching, drop actions as the key differentiator, and a final performance hardening pass to hit the <0.5% idle CPU / <50MB memory budget that separates Hoops from every competitor.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: App Shell & Window Foundation** - Agent app with borderless overlay positioned over notch (or virtual pill on non-notch Macs)
- [ ] **Phase 2: Notch Interaction** - Smooth hover-to-expand with spring animations, custom notch shape, and vibrancy
- [ ] **Phase 3: Media Player Widget** - Now-playing display with album art, controls, and dual-API media backend
- [ ] **Phase 4: HUD Replacement** - Volume and brightness sliders rendered inside the notch, replacing native HUD
- [ ] **Phase 5: Context Awareness** - Widget switching based on frontmost app, time of day, Focus Mode, and user rules
- [ ] **Phase 6: Drop Actions** - File drop zone on notch with built-in actions and Shortcuts/shell pipeline support
- [ ] **Phase 7: Performance & Polish** - Hit performance budget, validate sleep/wake resilience, end-to-end hardening

## Phase Details

### Phase 1: App Shell & Window Foundation
**Goal**: The app runs invisibly as a menu bar agent with a borderless overlay window correctly positioned over the hardware notch (or as a virtual pill on non-notch Macs)
**Depends on**: Nothing (first phase)
**Requirements**: SHELL-01, SHELL-02, SHELL-03, SHELL-04, WIND-01, WIND-02, WIND-03, WIND-04
**Success Criteria** (what must be TRUE):
  1. App launches with no dock icon; a gear icon appears in the menu bar that opens a settings window
  2. Borderless overlay window sits precisely over the hardware notch, matching its geometry
  3. On a non-notch Mac, a virtual pill appears at top-center of the screen
  4. Connecting an external monitor spawns a separate overlay instance on that screen
  5. App can be configured to launch at login and persists the setting across restarts
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md - Xcode project, agent app shell, MenuBarExtra, settings with launch-at-login
- [ ] 01-02-PLAN.md - NSPanel overlay, screen detection, notch geometry, multi-monitor window management

### Phase 2: Notch Interaction
**Goal**: Users can hover the notch area to smoothly expand it into a widget surface and dismiss it naturally
**Depends on**: Phase 1
**Requirements**: NOTCH-01, NOTCH-02, NOTCH-03, NOTCH-04, NOTCH-05
**Success Criteria** (what must be TRUE):
  1. Hovering the notch for 200ms triggers a spring-animated expansion at 60fps with no visual tearing
  2. Moving the mouse away, clicking outside, or pressing Escape collapses the notch smoothly
  3. The expanded notch shape blends seamlessly with the hardware notch edges (no visible seam or gap)
  4. Expanded state shows vibrancy/blur background; collapsed state is opaque dark matching the notch
  5. User can switch activation trigger to click or keyboard shortcut in settings
**Plans**: 2 plans

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD

### Phase 3: Media Player Widget
**Goal**: Users see what is playing and control playback directly from the notch
**Depends on**: Phase 2
**Requirements**: MEDIA-01, MEDIA-02, MEDIA-03, MEDIA-04, MEDIA-05, MEDIA-06
**Success Criteria** (what must be TRUE):
  1. When music is playing, expanding the notch shows album art, track title, artist, and a progress indicator
  2. Play/pause, next, and previous controls work and reflect the correct source app icon (Spotify, Apple Music, etc.)
  3. When collapsed, a subtle waveform animation and album art peek indicate active playback
  4. Two-finger horizontal swipe on the notch skips to the next or previous track
  5. Media data works via MediaRemote and falls back gracefully to MPNowPlayingInfoCenter if unavailable
**Plans**: 2 plans

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: HUD Replacement
**Goal**: Volume and brightness adjustments appear as slim sliders inside the notch instead of the native macOS HUD
**Depends on**: Phase 2
**Requirements**: HUD-01, HUD-02, HUD-03, HUD-04, HUD-05
**Success Criteria** (what must be TRUE):
  1. Pressing a volume key shows a slim volume slider inside the notch area (not the native macOS HUD)
  2. Pressing a brightness key shows a slim brightness slider inside the notch area
  3. Sliders auto-dismiss after a configurable timeout (default 2 seconds)
  4. User can grab and drag the slider to adjust volume or brightness interactively
**Plans**: 2 plans

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Context Awareness
**Goal**: The notch automatically shows relevant widgets based on what the user is doing
**Depends on**: Phase 3, Phase 4
**Requirements**: CTX-01, CTX-02, CTX-03, CTX-04
**Success Criteria** (what must be TRUE):
  1. Switching frontmost app changes which widgets appear in the expanded notch
  2. Widgets shift automatically based on time of day (morning/afternoon/evening profiles)
  3. Activating a macOS Focus Mode switches the notch to a different widget set
  4. User can create custom rules in settings ("When [condition] show [widgets]") that override defaults
**Plans**: 2 plans

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: Drop Actions
**Goal**: Users can drop files onto the notch to trigger instant automations
**Depends on**: Phase 2
**Requirements**: DROP-01, DROP-02, DROP-03, DROP-04, DROP-05
**Success Criteria** (what must be TRUE):
  1. Dragging a file over the notch reveals a drop zone UI; releasing the file triggers an action
  2. Built-in "compress/resize image" action processes a dropped image and copies the result to clipboard
  3. Built-in "OCR" action extracts text from a dropped image
  4. User can assign a macOS Shortcut as a drop action
  5. User can define multi-step drop pipelines chaining actions and shell scripts
**Plans**: 2 plans

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD

### Phase 7: Performance & Polish
**Goal**: The app meets its performance budget and handles all edge cases reliably
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4, Phase 5, Phase 6
**Requirements**: SHELL-05, WIND-05
**Success Criteria** (what must be TRUE):
  1. Idle CPU usage is below 0.5% and active CPU usage stays under 3% as measured by Activity Monitor
  2. Memory usage stays under 50MB during normal operation with all widgets loaded
  3. App survives sleep/wake cycles without window position bugs or overlay disappearing
  4. Display hotplug (connecting/disconnecting external monitor) correctly creates/removes overlay instances without crashes
**Plans**: 2 plans

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7
Note: Phases 3, 4, and 6 all depend on Phase 2 but not each other -- they could theoretically run in parallel.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Shell & Window Foundation | 0/0 | Not started | - |
| 2. Notch Interaction | 0/0 | Not started | - |
| 3. Media Player Widget | 0/0 | Not started | - |
| 4. HUD Replacement | 0/0 | Not started | - |
| 5. Context Awareness | 0/0 | Not started | - |
| 6. Drop Actions | 0/0 | Not started | - |
| 7. Performance & Polish | 0/0 | Not started | - |
