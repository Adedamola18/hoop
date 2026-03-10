# Competitive Research Report: macOS Notch Utility Apps
## Compiled March 9, 2026 — For "Hoops" Product Development

---

## 1. Complete Landscape of macOS Notch Apps

### 1.1 NotchNook (Paid — $3/mo or $25 one-time)
**What it does:** The most feature-rich commercial notch app. Expands the notch into a customizable widget surface with media player, calendar, shortcuts, mirror (webcam), file tray, and HUD replacement.

**Unique features:**
- Native widget system (Notes, Mirror, Calendar, Shortcuts)
- File Tray: drag files onto notch for temp storage, drag out to any app
- AirDrop integration from the notch
- HUD replacement for volume/brightness inside the notch
- Waveform visualization for now-playing audio
- Pinnable folders for Finder-free access

**Known issues (critical differentiators for Hoops):**
- Severe battery drain on M1 MacBook Pro (appears as top energy consumer)
- Memory leak: consumes 2GB+ RAM after running several hours, requires force quit
- Crash-on-launch bug on macOS 15.4+
- Music controls frequently non-functional (can't skip/pause/rewind)
- Dragging images from Finder duplicates files (Tray and Drop Zone both capture drag)
- macOS beta releases regularly break the app due to API dependencies
- Subscription model draws complaints ($3/mo or $25 one-time for 5 devices)

**Sources:**
- [MacSources Review](https://macsources.com/notchnook-mac-app-review/)
- [Setapp Customer Reviews](https://setapp.com/apps/notchnook/customer-reviews)
- [NotchNook Issues](https://www.notchnook.org/)

---

### 1.2 NotchDrop (Paid — ~$15 one-time)
**What it does:** File drop shelf in the notch with premium features for media, screen recording, and AI.

**Unique features:**
- File drop zone + clipboard history (free tier)
- Screen recording with smart zoom
- Face-cam overlay for recordings
- Local file sharing
- AI Chat directly from the notch (brainstorming, answers)
- Notes with Voice AI: voice recordings auto-transcribed, summarized, organized by AI
- Todo list

**Pricing model:** One-time purchase (~$15 Pro), no subscription. Free tier includes file drop + clipboard.

**Sources:**
- [NotchDrop Official](https://www.notchdrop.com/)
- [FunBlocks Review](https://www.funblocks.net/aitools/reviews/notchdrop)
- [App Store](https://apps.apple.com/us/app/notchdrop/id6529528324?mt=12)

---

### 1.3 Boring Notch / TheBoringNotch (Free, Open Source)
**What it does:** Open-source notch enhancement focused on music controls and system indicators.

**Unique features:**
- Music controls with audio visualizer and adaptive album art colors
- Battery indicator in notch
- Calendar and Reminders integration
- macOS HUD replacement (volume/brightness)
- File shelf with AirDrop support
- Camera preview/mirror
- Clipboard monitor: tracks copied text in real-time with originating app icon, searchable history of last 48 items
- Pomodoro timer

**Known issues:**
- Battery drain: ~5% per hour while idle on M4 MacBook Pro, 3% drain in sleep mode
- Notch crashes/disappears after long sleep cycles
- 6.8k GitHub stars, 523 forks, 1 main contributor, 209 open issues

**Open feature requests on GitHub:**
- Mirror functionality (like Hand Mirror but in notch)
- Functional animations (like RunCat CPU monitor)
- Discord-based prereleases requested on GitHub instead
- More shelf improvements

**Sources:**
- [GitHub Repo](https://github.com/TheBoredTeam/boring.notch/)
- [Official Site](https://theboring.name/)
- [Battery Bug](https://github.com/TheBoredTeam/boring.notch/issues/338)

---

### 1.4 Alcove (Paid — $17 one-time)
**What it does:** Dynamic Island experience with focus on fluid animations and system HUDs.

**Unique features:**
- Beautiful, polished animations closest to iPhone Dynamic Island feel
- Customizable HUDs for volume/brightness
- Live activity widgets (battery, sound levels, display brightness)
- Lock screen widget support (unique — no other notch app does this)
- Swipe gestures
- Background app controls (YouTube, Netflix)
- 48-hour free trial

**Notable:** Developer specifically mentioned that lock screen support was the hardest feature to build, with zero documentation available from Apple.

**Sources:**
- [Club MacStories Review](https://club.macstories.net/posts/alcove-an-excellent-notch-utility-with-beautiful-animations)
- [Developer Story](https://medium.com/@teslathewest/the-story-behind-alcove-macos-dynamic-island-app-dadb5d97e8b0)
- [Official Site](https://tryalcove.com/)

---

### 1.5 TopNotch (Free)
**What it does:** Simply hides the notch by making the menu bar black.

**Features:** Supports dynamic desktop wallpapers, multiple displays, adds rounded corners to wallpaper. Made by creators of CleanShot X. Purely cosmetic.

**Sources:**
- [Official Site](https://topnotch.app/)
- [9to5Mac Review](https://9to5mac.com/2021/10/28/third-party-apps-to-hide-the-new-macbook-pros-notch-are-here/)

---

### 1.6 MediaMate (Paid — ~$9.20)
**What it does:** Replaces default macOS volume/brightness indicators with iOS-style interactive sliders.

**Unique features:**
- Four indicator styles, including a "Notch" style that expands the hardware notch
- Device-specific icons (AirPods, AirPods Max, Beats)
- Playback controls with app exclusion rules
- Timing rules for UI display duration
- Available via Gumroad

**Sources:**
- [MacStories Review](https://www.macstories.net/reviews/notchnook-and-mediamate-two-apps-to-add-a-dynamic-island-to-the-mac/)

---

### 1.7 Notchmeister (Free)
**What it does:** Purely visual — adds fun visual effects to the notch area.

**Effects:** Glow (cursor lighting), Cylon, Plasma Leak, Festive, Nano Radar, Expando, Fusion Dice, AutoToot. Made by The Iconfactory. Includes a "replacement notch" for non-notch Macs.

**Sources:**
- [App Store](https://apps.apple.com/us/app/notchmeister/id1599169747)

---

### 1.8 Perch / Dynamic Notch Island (Paid)
**What it does:** Minimal shelf that slides from the notch with workflow tools.

**Unique features:**
- Completely on-device and private (no internet required)
- Media controls, live weather, camera access
- Calendar with predefined timers/stopwatch (Pomodoro, cooking)
- Full-screen mode support (works even in fullscreen apps)
- File tray for drag-and-drop

**Sources:**
- [App Store](https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228?mt=12)
- [Product Hunt](https://www.producthunt.com/products/perch-7)

---

### 1.9 FocusNotch (Paid)
**What it does:** Turns the notch into a focus/productivity timer with website blocking.

**Unique features:**
- Persistent progress timer in the notch
- Website blocker at network extension level during focus sessions
- Timer always visible but non-intrusive

**Sources:**
- [App Store](https://apps.apple.com/gb/app/focusnotch/id6741244268?mt=12)

---

### 1.10 NotchNest (Paid)
**What it does:** Newer entrant focused on performance.

**Claims:** Zero performance impact, lightweight, optimized for Apple Silicon. Lighter, faster, more efficient with memory and CPU than competitors. Developing Liquid Glass UI option and music player glow toggles.

**Sources:**
- [App Store](https://apps.apple.com/us/app/notchnest-power-your-notch/id6747612321?mt=12)

---

### 1.11 NotchBox (Paid)
**What it does:** Drag-and-drop focused, with music controls and calendar.

**Sources:**
- [App Store](https://apps.apple.com/us/app/notchbox-easier-drag-drop/id6737410946?mt=12)

---

### 1.12 QuakeNotch
**What it does:** Dropdown terminal emulator from the notch area.

**Unique features:**
- AI-powered: describe tasks in plain English, AI generates terminal commands
- Context-aware code assistance, debugging, intelligent suggestions
- Smart workflow understanding

**Sources:**
- [Official Site](https://quakenotch.com/)

---

## 2. Open-Source Projects on GitHub

| Project | Stars | Key Tech | Notable Features |
|---------|-------|----------|-----------------|
| [boring.notch](https://github.com/TheBoredTeam/boring.notch/) | 6.8k | SwiftUI | Music controls, visualizer, HUD, shelf, calendar |
| [Atoll](https://github.com/Ebullioscopic/Atoll) | Active | SwiftUI, Combine, AVFoundation, IOKit | Media/Stats/Timers/Clipboard tabs, audio visualiser with spectrum analysis, adaptive artwork colors |
| [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit) | Active | SwiftUI | Framework/SDK for building notch apps. DynamicNotch, DynamicNotchInfo, DynamicNotchProgress classes. Non-notch Mac support. |
| [MacIsland](https://github.com/RKInnovate/MacIsland) | Active | SwiftUI | Notification pop-ups, battery status, music control, AirDrop, temp file storage |
| [NotchBar](https://github.com/navtoj/NotchBar) | Active | SwiftUI | Customizable widgets around the notch |
| [mew-notch](https://github.com/monuk7735/mew-notch) | Active | SwiftUI | Smooth animations, modern macOS styling |
| [dynamicNotch](https://github.com/Mosrepos/dynamicNotch) | Active | — | Dynamic Island for Mac |

**Key takeaway:** DynamicNotchKit is a reusable framework that could accelerate development. Atoll has the most technically sophisticated approach with spectrum analysis and adaptive theming.

---

## 3. iOS Dynamic Island Features NOT Yet on macOS

These iOS Dynamic Island capabilities are absent or poorly implemented in existing macOS notch apps:

### 3.1 Live Activities Ecosystem
- **Food delivery tracking** (Uber Eats, DoorDash showing ETA in compact mode)
- **Sports scores** updating in real-time in the pill
- **Ride-sharing** (Uber showing driver arrival)
- **Flight tracking** (gate changes, boarding status)
- **Cooking timers** with step-by-step progression (Pestle app)

**macOS equivalent opportunity:** Package delivery tracking, build status (Xcode), deployment progress, download progress for any app, meeting countdown.

### 3.2 Interaction Patterns
- **Long-press to expand** with rich preview (Overcast: long-press to skip 30s)
- **Navigation turn-by-turn** in compact mode (Waze shows speed limits/turns when closed)
- **Split pill** showing two activities simultaneously (timer + music)
- **Tap-through to source app** from any Live Activity

**macOS equivalent opportunity:** Split pill showing two widgets simultaneously (e.g., timer + now-playing). Long-press for quick actions without full expansion.

### 3.3 System Integration
- **Face ID animation** blending into the island
- **AirDrop progress** inside the island
- **Phone call** controls in the island
- **NFC/Apple Pay** visual feedback

**macOS equivalent opportunity:** AirDrop progress in notch, SharePlay indicators, Continuity Camera status, Handoff visual indicator.

---

## 4. User Complaints & Wishlist (Aggregated)

### 4.1 Universal Complaints Across All Apps
1. **Battery drain** — The #1 complaint. Users report 4-5% per hour drain even idle.
2. **Memory leaks** — NotchNook specifically cited for 2GB+ after hours of use.
3. **Sleep/wake crashes** — Notch disappears or crashes after sleep cycles.
4. **macOS update breakage** — Apps break with every macOS point release due to private API dependencies.
5. **Subscription fatigue** — Users strongly prefer one-time purchase over subscription.
6. **Too many features crammed in** — Some apps feel bloated rather than focused.

### 4.2 Feature Wishlist (from forums, GitHub issues, reviews)
1. **More music service support** — Tidal, YouTube Music, browser-based players
2. **Persistent expanded mode option** — Keep shortcuts/widgets always visible
3. **Multiple focus timers with breaks** — Pomodoro-style with scheduling
4. **Website whitelist/blacklist** tied to focus modes
5. **Download progress indicator** for Safari, Chrome, Firefox
6. **RunCat-style CPU/system animation** in the notch
7. **Clipboard history with search** — More than just recent items
8. **Better multi-monitor support** — Different configs per display
9. **Pixel-perfect notch alignment** — Some apps don't line up with physical notch
10. **Lock screen support** — Only Alcove attempts this
11. **AI integration** — Summarization, quick chat, command generation
12. **Quick notes** directly in the notch
13. **Third-party widget SDK** — No app has shipped this yet

---

## 5. Critical Market Context: The Notch Is Disappearing

### MacBook Pro 2026 (Late 2026)
- Apple is replacing the notch with a **hole-punch camera + Dynamic Island** on OLED MacBook Pros
- These will be **touchscreen** with touch-friendly macOS controls
- Apple will bring **native Live Activities API to macOS**
- Sources: Bloomberg's Mark Gurman, analyst Ross Young, Omdia roadmap

### MacBook Air
- Will **retain the notch through 2028** according to Omdia

### Implications for Hoops
- **Short-term (2026-2028):** Millions of notch MacBooks still in use, plus MacBook Air continuing with notch
- **Medium-term (2027+):** Must plan for Dynamic Island / hole-punch transition
- **Strategic advantage:** Building a flexible architecture now that supports both notch AND hole-punch/Dynamic Island puts Hoops ahead of competitors when Apple ships native support
- **Risk:** Apple's native Dynamic Island could make third-party apps redundant for basic features. Differentiation must come from deeper customization and features Apple won't build.

---

## 6. Performance & Technical Approaches

### What Works
- **Zero CPU when hidden:** Monit widget achieves this by only activating helper when visible
- **NotchNest claims:** Zero performance impact, optimized for Apple Silicon
- **Atoll approach:** SwiftUI + Combine + AVFoundation + IOKit for native integration with minimal overhead
- **drawingGroup():** SwiftUI modifier that flattens complex views into a single Metal render pass

### What Fails
- **Continuous animation loops** drain battery even when hidden
- **Polling-based state checks** instead of event-driven observation
- **SwiftUI re-render storms** from improper state management (known issue in Apple Developer Forums)
- **Bridging AppKit and SwiftUI** without proper management causes memory leaks

### Recommended Approach for Hoops
1. Event-driven architecture (not polling) for all system state (battery, volume, media)
2. `drawingGroup()` on animated views (waveforms, visualizers)
3. Lazy view instantiation — don't create widget views until first expansion
4. `TimelineView` only for active animations, paused when collapsed
5. Profile with Instruments from day one; set hard budgets (< 0.5% idle CPU, < 50MB RAM)
6. Use `NSPanel` with `nonactivatingPanel` to avoid focus stealing

---

## 7. Differentiation Opportunities for Hoops

Based on gaps in the competitive landscape:

### 7.1 Performance as a Feature
No competitor has solved the battery drain problem. Achieving genuinely zero-impact idle performance would be the single biggest differentiator. Market with measurable claims: "0.0% CPU when idle. Verified."

### 7.2 Split-Pill Display (iOS-Inspired)
No macOS app implements the iOS split-pill pattern where two activities show simultaneously (e.g., timer on left, now-playing on right) in collapsed mode.

### 7.3 Live Activities Protocol
Create a public API/protocol that any macOS app can adopt to push live status to the notch. No competitor has shipped a third-party SDK. This would create a platform/ecosystem moat.

### 7.4 Context-Aware Intelligence
- Show meeting countdown when calendar event approaching
- Show build status when Xcode is frontmost app
- Show git status when Terminal is active
- Show download progress when browser is downloading
- Adapt widgets based on time of day / focus mode

### 7.5 Graceful Notch-to-Island Transition
Build architecture that works with both current notch AND future hole-punch/Dynamic Island MacBooks. First app to seamlessly support both form factors wins.

### 7.6 Privacy-First, On-Device
Perch markets "completely on-device, no internet required." Lean into this: no telemetry, no network calls, no accounts. Especially important as competitors add AI features requiring cloud.

### 7.7 Focus/Productivity Mode
FocusNotch proves demand exists for focus timers in the notch. Combine with website blocking, app blocking, and Pomodoro sequences with break management.

### 7.8 Drop Actions / Automations
NotchNook's PRD mentions "Pipelines" (drop file to run action) but hasn't shipped it. First to market with: drop image to compress, drop file to upload and get link, drop text to translate.

### 7.9 Haptic-Quality Animations
Alcove is praised for animation quality. Invest in spring physics, morphing transitions, and micro-interactions that feel as good as iOS Dynamic Island.

### 7.10 Robust Sleep/Wake Handling
Every competitor has bugs around sleep/wake cycles. Solving this basic reliability issue creates trust.

---

## 8. Pricing Intelligence

| App | Model | Price | Notes |
|-----|-------|-------|-------|
| NotchNook | Subscription or one-time | $3/mo or $25 | Also on Setapp |
| NotchDrop | Freemium + one-time | ~$15 Pro | Free tier with file drop + clipboard |
| Alcove | One-time | $17 | 48-hour free trial |
| MediaMate | One-time | $9.20 | Via Gumroad |
| Boring Notch | Free | $0 | Open source |
| TopNotch | Free | $0 | — |
| Notchmeister | Free | $0 | — |
| FocusNotch | Paid | TBD | App Store |
| NotchNest | Paid | TBD | App Store |
| Perch | Paid | TBD | App Store |

**Market insight:** Users strongly prefer one-time purchase. Subscription model generates complaints. Sweet spot appears to be $15-25 one-time with optional free tier for basic features.

---

## 9. Summary: Top 10 Takeaways for Hoops

1. **Battery drain is the #1 unsolved problem** — solving it is the biggest differentiator
2. **The notch is disappearing from MacBook Pro in late 2026** but persists on Air through 2028; architecture must support both notch and future Dynamic Island
3. **No app has shipped a widget SDK/protocol** for third-party integration — first mover advantage available
4. **iOS split-pill and long-press patterns** haven't been brought to macOS
5. **Sleep/wake reliability** is broken in every competitor
6. **One-time pricing at $15-20** is the market sweet spot
7. **AI features are emerging** (NotchDrop, QuakeNotch) but no one has done it well yet
8. **Context-awareness** (adapting to frontmost app, time of day) is unexplored territory
9. **Open-source competition** (Boring Notch at 6.8k stars) means the basic feature set is free — Hoops must offer something meaningfully better
10. **Apple's native Dynamic Island for macOS** is the existential risk — differentiate with customization depth, automation, and SDK that Apple won't provide
