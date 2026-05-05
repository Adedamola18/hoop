# NotchNook v2 - Development Guidelines

## Project Context

- **App**: NotchNook v2 - macOS notch utility app
- **Platform**: macOS 14.0+ (Sonoma), Swift 5.9+, SwiftUI + AppKit interop
- **App type**: LSUIElement agent (no dock icon), NSPanel-based overlay
- **Bundle ID**: com.hoops.notchnook
- **Xcode project**: Hoop.xcodeproj with scheme "Hoop"
- **Build verification**: `xcodebuild build -project Hoop.xcodeproj -scheme Hoop` or `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 <files>`

## Code Structure

- Use Swift's latest features and protocol-oriented programming
- Prefer value types (structs) over classes where appropriate
- Use MVVM architecture with SwiftUI
- Follow Apple's Human Interface Guidelines for macOS
- Project layout:
  ```
  Hoop/
    Models/       -- Data models, state, protocols
    Services/     -- @Observable service layer (media, HUD, battery, etc.)
    Views/        -- SwiftUI views and AppKit wrappers
      Widgets/    -- Individual widget views
    Window/       -- NSPanel, window manager, screen detection
  ```

## Naming Conventions

- camelCase for variables and functions, PascalCase for types/protocols
- Verbs for methods (`fetchData`, `startObserving`, `stopMonitoring`)
- Boolean prefixes: `is`, `has`, `should` (e.g., `isPlaying`, `hasNotch`)
- Clear, descriptive names following Apple style

## Swift Best Practices

- Strong type system with proper optional handling
- async/await for concurrency
- Result type for error propagation
- All services use @Observable (Observation framework), NOT @Published/ObservableObject
- Prefer `let` over `var`
- Protocol extensions for shared behavior
- Use `SettingsLink` (built-in), not third-party settings packages
- `SMAppService` as sole source of truth for launch-at-login (no UserDefaults mirror)

## UI Development

- SwiftUI first, AppKit (NSViewRepresentable) when needed for macOS-specific features
- SF Symbols for icons
- Support dark mode and vibrancy
- Use GeometryReader and proper layout for adaptive sizing
- `drawingGroup()` on animated views for Metal-backed rendering is OK
- NEVER use `drawingGroup()` on outer containers (breaks NSVisualEffectView behind-window blending)

## Performance

- Profile with Instruments
- Lazy load views where appropriate
- Background task handling with proper threading
- Proper state management to minimize unnecessary re-renders
- Memory management - avoid retain cycles in closures

## State & Data Flow

- All services owned by NotchWindowManager (single instance each, shared across panels)
- New services must be added to NotchWindowManager (init, start/stopObserving) and passed to NotchRootView
- UserDefaults for preferences
- Combine for reactive code where Observation framework doesn't fit
- Clean dependency injection through view constructors

## macOS-Specific Patterns

- NSScreen notch detection via `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
- MediaRemote is a private framework loaded via dlopen/dlsym
- MediaRemote commands: 2=togglePlayPause, 4=next, 5=previous (UInt32)
- CoreAudio volume: AudioObjectAddPropertyListenerBlock on kAudioHardwareServiceDeviceProperty_VirtualMainVolume
- IOKit brightness: adaptive polling (1s idle, 0.1s when HUD active) via IODisplayGetFloatParameter
- Carbon.HIToolbox for key code constants (kVK_ANSI_*) and UCKeyTranslate
- HUD phase is separate from expanded phase (saves/restores previous phase)
- HUD frame: 400pt x 60pt. Expanded frame: configurable width (400-800pt) x 200pt

## Security

- Encrypt sensitive data when needed
- Use Keychain for secure storage
- Proper entitlements and sandbox configuration
- Input validation at system boundaries

## Testing & Quality

- ALL commits must pass `swiftc -typecheck` for modified files
- Do NOT commit broken code
- SourceKit noise: single-file swiftc diagnostics can give false errors; verify with multi-file swiftc including all dependent files
- Keep changes focused and minimal
- Follow existing code patterns

## Adding Files to Xcode Project

When creating new Swift files, you MUST update `Hoop.xcodeproj/project.pbxproj`:

1. Generate a unique 24-char hex ID (CHECK for collisions first!)
2. Add `PBXFileReference` entry for the file
3. Add `PBXBuildFile` entry referencing the file reference
4. Add the file reference to the appropriate `PBXGroup` children array
5. Add the build file to `PBXSourcesBuildPhase` files array

Known PBXGroup IDs:
- Services: AA000036
- Widgets: AA000037
- New IDs use BB0000xx prefix (BB000001-BB000008 already used)

## Critical Gotchas

- **ID collisions in project.pbxproj**: When generating 24-char hex IDs, ensure they don't collide with existing IDs. Previous collisions caused "project is damaged" errors.
- **drawingGroup() + vibrancy**: Never wrap the outer NotchRootView container in drawingGroup(). It composites into an offscreen Metal buffer, breaking NSVisualEffectView blending.
- **SourceKit noise**: Single-file swiftc diagnostics can give false errors. Always verify with multi-file swiftc including all dependent files.
- **Shortcuts CLI**: `/usr/bin/shortcuts run "Name" --input-path <path>` for file input
- **Shell scripts**: Process() with /bin/zsh -c, file path passed as $1 via "--" separator
