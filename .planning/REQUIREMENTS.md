# Requirements: Hoops

**Defined:** 2026-03-09
**Core Value:** The notch overlay must expand/collapse flawlessly with zero visual glitches and negligible performance impact

## v1 Requirements

### App Shell

- [x] **SHELL-01**: App runs as LSUIElement agent with no dock icon
- [x] **SHELL-02**: Menu bar status item (gear icon) opens settings
- [x] **SHELL-03**: Settings window with appearance, widget, and behavior configuration
- [x] **SHELL-04**: Launch at login via SMAppService
- [ ] **SHELL-05**: App uses <50MB memory and <0.5% idle CPU

### Window & Detection

- [ ] **WIND-01**: Borderless NSPanel overlay positioned over hardware notch
- [ ] **WIND-02**: Screen detector identifies notch presence and calculates geometry
- [ ] **WIND-03**: Non-notch Mac support with virtual pill at top-center
- [ ] **WIND-04**: Multi-monitor support with per-screen window instances
- [ ] **WIND-05**: Window survives sleep/wake and display hotplug without position bugs

### Notch Interaction

- [ ] **NOTCH-01**: Expand on hover with 200ms dwell delay and spring animation at 60fps
- [ ] **NOTCH-02**: Collapse on mouse exit (300ms grace) or click outside or Escape
- [ ] **NOTCH-03**: Custom notch Shape that blends seamlessly with hardware notch
- [ ] **NOTCH-04**: Vibrancy/blur background in expanded state, opaque dark when collapsed
- [ ] **NOTCH-05**: Configurable activation trigger (hover/click/keyboard shortcut)

### Media Player

- [ ] **MEDIA-01**: Display album art, track title, artist name, playback progress
- [ ] **MEDIA-02**: Play/pause, next, previous controls
- [ ] **MEDIA-03**: Detect and show source app icon (Spotify, Apple Music, etc.)
- [ ] **MEDIA-04**: Collapsed live activity showing waveform animation and album art peek
- [ ] **MEDIA-05**: MediaRemote primary with MPNowPlayingInfoCenter fallback
- [ ] **MEDIA-06**: Two-finger horizontal swipe to skip track

### HUD Replacement

- [ ] **HUD-01**: Volume slider rendered inside notch on volume key press
- [ ] **HUD-02**: Brightness slider rendered inside notch on brightness key press
- [ ] **HUD-03**: Auto-dismiss after configurable timeout (default 2s)
- [ ] **HUD-04**: Interactive slider (user can grab to adjust)
- [ ] **HUD-05**: Best-effort native HUD suppression with graceful fallback

### Context Awareness

- [ ] **CTX-01**: Detect frontmost app and adapt visible widgets
- [ ] **CTX-02**: Time-of-day widget profiles (morning/afternoon/evening)
- [ ] **CTX-03**: macOS Focus Mode integration (show different widgets per focus)
- [ ] **CTX-04**: User-configurable rules engine ("When [condition] show [widgets]")

### Drop Actions

- [ ] **DROP-01**: Drop file onto notch triggers drop zone UI
- [ ] **DROP-02**: Built-in action: compress/resize image, copy result to clipboard
- [ ] **DROP-03**: Built-in action: OCR text extraction from dropped image
- [ ] **DROP-04**: Shortcuts integration for custom drop actions
- [ ] **DROP-05**: User-definable drop pipelines (chain actions, shell scripts)

## v2 Requirements

### Calendar Widget

- **CAL-01**: Show today's date and upcoming events (next 24h)
- **CAL-02**: Horizontal swipe to browse adjacent days
- **CAL-03**: Tap event to open in Calendar.app
- **CAL-04**: Color-coded by calendar source

### File Shelf

- **SHELF-01**: Persistent tray with file thumbnails
- **SHELF-02**: Drag files out of tray to any destination
- **SHELF-03**: AirDrop integration via NSSharingService
- **SHELF-04**: Security-scoped bookmarks for cross-session persistence

### Mirror Widget

- **MIRR-01**: One-click webcam activation with live preview
- **MIRR-02**: Mirror/flip toggle

### Shortcuts Widget

- **SHRT-01**: Configurable grid of user-selected Shortcuts
- **SHRT-02**: Tap to run, show result briefly

### Split-Pill Display

- **SPLT-01**: Show two simultaneous live activities side-by-side
- **SPLT-02**: Each pill independently expandable

### Third-Party Widget SDK

- **SDK-01**: Swift Package-based plugin protocol
- **SDK-02**: Sandboxed widget execution

## Out of Scope

| Feature | Reason |
|---------|--------|
| Mac App Store distribution | Private API usage (MediaRemote) makes v1 ineligible |
| Real-time notifications in notch | Requires Notification access, high complexity, v2+ |
| Collaborative shelf (Bonjour) | Networking complexity, v2+ |
| AI/LLM integration | Dependency on local models, v2+ |
| Clipboard history widget | Not core to notch experience, v2+ |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SHELL-01 | Phase 1 | Complete |
| SHELL-02 | Phase 1 | Complete |
| SHELL-03 | Phase 1 | Complete |
| SHELL-04 | Phase 1 | Complete |
| SHELL-05 | Phase 7 | Pending |
| WIND-01 | Phase 1 | Pending |
| WIND-02 | Phase 1 | Pending |
| WIND-03 | Phase 1 | Pending |
| WIND-04 | Phase 1 | Pending |
| WIND-05 | Phase 7 | Pending |
| NOTCH-01 | Phase 2 | Pending |
| NOTCH-02 | Phase 2 | Pending |
| NOTCH-03 | Phase 2 | Pending |
| NOTCH-04 | Phase 2 | Pending |
| NOTCH-05 | Phase 2 | Pending |
| MEDIA-01 | Phase 3 | Pending |
| MEDIA-02 | Phase 3 | Pending |
| MEDIA-03 | Phase 3 | Pending |
| MEDIA-04 | Phase 3 | Pending |
| MEDIA-05 | Phase 3 | Pending |
| MEDIA-06 | Phase 3 | Pending |
| HUD-01 | Phase 4 | Pending |
| HUD-02 | Phase 4 | Pending |
| HUD-03 | Phase 4 | Pending |
| HUD-04 | Phase 4 | Pending |
| HUD-05 | Phase 4 | Pending |
| CTX-01 | Phase 5 | Pending |
| CTX-02 | Phase 5 | Pending |
| CTX-03 | Phase 5 | Pending |
| CTX-04 | Phase 5 | Pending |
| DROP-01 | Phase 6 | Pending |
| DROP-02 | Phase 6 | Pending |
| DROP-03 | Phase 6 | Pending |
| DROP-04 | Phase 6 | Pending |
| DROP-05 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-03-09*
*Last updated: 2026-03-09 after roadmap creation*
