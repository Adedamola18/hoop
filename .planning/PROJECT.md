# Hoops

## What This Is

A lightweight macOS utility app that transforms the MacBook notch (or top-center screen area on non-notch Macs) into an interactive, expandable widget surface — bringing Dynamic Island-style functionality to macOS. Hoops sits seamlessly around the notch, providing contextual information (now playing, system HUD), quick actions (file drop automations), and context-aware widget switching — all activated by hovering the notch area.

## Core Value

The notch overlay must expand/collapse flawlessly with zero visual glitches and negligible performance impact — if it stutters, drains battery, or feels janky, nothing else matters.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Borderless overlay window that blends with hardware notch
- [ ] Smooth expand/collapse on hover with spring animations
- [ ] Now-playing media widget (album art, title, controls)
- [ ] Volume/brightness HUD replacement with slim slider
- [ ] Context-aware widget switching (adapt to frontmost app, time, Focus Mode)
- [ ] Drop actions: drop file on notch to trigger automations
- [ ] Non-notch Mac support (virtual pill)
- [ ] Settings via menu bar status item
- [ ] Launch at login

### Out of Scope

- Calendar widget — deferred to v2 (core first)
- Mirror/webcam widget — deferred to v2
- Shortcuts widget — deferred to v2
- File shelf/tray (persistent storage) — deferred to v2 (drop actions cover immediate use case)
- Split-pill display — deferred to v2
- Third-party widget SDK — deferred to v2+
- Collaborative shelf — deferred to v2+
- Notification relay — deferred to v2+
- Mac App Store distribution — v1 ships direct download only

## Context

- MacBook Pro notch: ~200pt wide, ~32pt tall. Camera housing is centered.
- Apple is shipping hole-punch + Dynamic Island on OLED MacBook Pros (late 2026). MacBook Air keeps notch through 2028. Architecture must support both form factors.
- Competitive landscape: 12+ apps exist (NotchNook, Boring Notch, NotchDrop, Alcove, etc.). #1 user complaint across all: battery drain (4-5%/hr idle). Sleep/wake bugs are universal.
- Boring Notch (open-source, 6.8k stars) is the main free competitor. NotchNook is the main paid competitor on Setapp.
- MediaRemote is a private framework — abstractions needed for future-proofing.
- Pricing sweet spot: $15-20 one-time purchase.

## Constraints

- **Platform**: macOS 14.0+ (Sonoma and later), Swift 5.9+, SwiftUI + AppKit interop
- **App identity**: LSUIElement agent (no dock icon), NSPanel-based overlay
- **Performance**: <0.5% idle CPU, <3% active CPU, <50MB memory, 60fps animations
- **API strategy**: Abstract media behind protocol — private API (MediaRemote) primary, public API (MPNowPlayingInfoCenter) fallback
- **Distribution**: Direct download (DMG, notarized). No App Store for v1.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Core-first v1 scope | Polish and performance > feature count. Competitors lose on battery/jank. | — Pending |
| Both API paths (private + public) | Keeps App Store option open. MediaRemote richer but fragile across OS updates. | — Pending |
| Context-aware in v1 | Unexplored by competitors. Major differentiator. | — Pending |
| Drop actions in v1 | Discussed but unshipped by every competitor. Unique value prop. | — Pending |
| Direct download distribution | Private API usage makes App Store ineligible for v1. | — Pending |

---
*Last updated: 2026-03-09 after initialization*
