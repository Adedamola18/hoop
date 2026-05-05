# Hoop

**Your MacBook notch, upgraded.**

A macOS utility that transforms the MacBook notch into a dynamic control center — media player, widgets, HUD, file drop zone, and more.


## Features

### Media Player
- Inline controls for Spotify and Apple Music
- Album art, track info, and progress bar
- Swipe gestures to skip tracks
- Works on macOS 14+ with app-specific fallbacks when MediaRemote returns empty data

### Widgets
Open the widget drawer to access:
- **Clipboard History** — recent copies, one-click paste
- **Timer / Stopwatch** — quick countdown or stopwatch
- **Calendar** — today's events via EventKit
- **Notes** — quick capture scratch pad
- **Shortcuts** — run your Shortcuts from the notch
- **Color Picker** — pick and copy colors from screen
- **Unit Converter** — length, weight, temperature, etc.
- **Webcam Mirror** — quick camera preview
- **System Stats** — CPU and memory at a glance

### HUD
- Volume and brightness sliders replace the default macOS HUD
- Best-effort native HUD suppression
- Appears in-notch, dismisses automatically

### Drop Zone
Drag files onto the notch to trigger actions:
- **Built-in**: compress image, OCR text extraction
- **Shortcuts**: pipe files through any Shortcut
- **Shell scripts**: custom processing pipelines
- Chain actions together with pipeline support

### Context Rules
The notch adapts automatically:
- **App-based** — show specific widgets per frontmost app
- **Time-based** — different layouts for morning, work, evening
- **Focus Mode** — respect macOS Focus settings

### Privacy Indicators
- Camera and microphone in-use indicators
- Screen recording indicator with pulsing dot

## Requirements

- macOS 14.0 (Sonoma) or later
- MacBook with notch (M1 Pro/Max or later)

## Build

```bash
xcodebuild build -project Hoop.xcodeproj -scheme Hoop
```

Or open `Hoop.xcodeproj` in Xcode and hit Run.

## How It Works

Hoop runs as a menu bar agent (no dock icon). An `NSPanel` overlay sits on top of the notch and responds to hover, click, or global hotkey. The panel uses a custom concave notch shape with spring animations for expand/collapse transitions, backed by `NSVisualEffectView` for vibrancy.

Services are `@Observable` singletons managed by `NotchWindowManager`. Media playback uses Apple's private `MediaRemote.framework` via `dlopen`, with Spotify distributed notifications and Apple Music AppleScript polling as fallbacks.

## License

All rights reserved.

## Author

Made by **Damola Olutoke**
