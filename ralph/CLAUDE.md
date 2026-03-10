# Ralph Agent Instructions

You are an autonomous coding agent working on **NotchNook v2**, a macOS notch utility app (Swift/SwiftUI/AppKit).

## Project Context

- **Platform**: macOS 14.0+ (Sonoma), Swift 5.9+, SwiftUI + AppKit interop
- **App type**: LSUIElement agent (no dock icon), NSPanel-based overlay
- **Build verification**: Use `xcodebuild build -project Hoop.xcodeproj -scheme Hoop` OR `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 <files>` to verify compilation.
- **Bundle ID**: com.hoops.notchnook
- **Xcode project**: Hoop.xcodeproj with scheme "Hoop"

### Existing Structure (v1 complete)

```
Hoop/
  NotchNookApp.swift       -- @main App with MenuBarExtra + Settings scenes
  AppDelegate.swift        -- NSApplicationDelegate, creates NotchWindowManager
  Info.plist               -- LSUIElement=true agent config
  Models/
    NotchState.swift       -- @Observable NotchState with Phase enum, ActivationTrigger
    ContextRule.swift       -- ContextRule model for app/time/focus-based widget switching
  Services/
    MediaService.swift     -- @Observable, MediaRemote dlopen/dlsym, NowPlayingInfo
    HUDService.swift       -- @Observable, CoreAudio volume + IOKit brightness monitoring
    ContextService.swift   -- @Observable, frontmost app detection, rule evaluation
    DropActionService.swift -- @Observable, file drag-and-drop actions, pipelines
  Views/
    NotchRootView.swift    -- Main view with NotchShape, phase-based content switching
    NotchShape.swift       -- Custom Shape with concave notch cutout
    SettingsView.swift     -- Settings window (General tab)
    VisualEffectView.swift -- NSVisualEffectView wrapper (NSViewRepresentable)
    HUDOverlayView.swift   -- Volume/brightness HUD slider display
    DropZoneView.swift     -- File drop zone indicator
    DropActionSelectionView.swift -- Action selection after file drop
    Widgets/
      MediaPlayerWidget.swift       -- Expanded media controls
      CollapsedMediaIndicator.swift -- Album art peek + waveform bars
  Window/
    NotchWindowManager.swift -- Central manager: owns all services, creates/positions panels
    NotchPanel.swift         -- NSPanel subclass with tracking areas, gesture handling
    ScreenDetector.swift     -- Notch detection, screen enumeration
```

### Key Patterns

- Use `SettingsLink` (built-in) not SettingsAccess SPM package
- `SMAppService` as sole source of truth for launch-at-login (no UserDefaults mirror)
- Verify compilation with: `swiftc -typecheck -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos14.0 <file.swift>`
- When creating new .swift files, they must also be added to `Hoop.xcodeproj/project.pbxproj` (PBXFileReference, PBXBuildFile, PBXGroup children, PBXSourcesBuildPhase)
- NSScreen notch detection uses `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`
- MediaRemote is a private framework loaded via dlopen/dlsym
- MediaRemote commands: 2=togglePlayPause, 4=next, 5=previous (UInt32)
- All services are @Observable (Observation framework), NOT @Published/ObservableObject
- All services are owned by NotchWindowManager (single instance each, shared across panels)
- `drawingGroup()` on animated views for Metal-backed rendering is OK, but do NOT use drawingGroup() on the outer container (it breaks NSVisualEffectView behind-window blending)
- HUD phase is separate from expanded phase — saves/restores previous phase
- HUD frame: 400pt x 60pt. Expanded frame: configurable width (400-800pt) x 200pt
- CoreAudio volume: AudioObjectAddPropertyListenerBlock on kAudioHardwareServiceDeviceProperty_VirtualMainVolume
- IOKit brightness: adaptive polling (1s idle, 0.1s when HUD active) via IODisplayGetFloatParameter
- Carbon.HIToolbox for key code constants (kVK_ANSI_*) and UCKeyTranslate
- Services PBXGroup ID: AA000036
- Widgets PBXGroup ID: AA000037
- Shortcuts CLI: `/usr/bin/shortcuts run "Name" --input-path <path>` for file input
- Shell scripts: Process() with /bin/zsh -c, file path passed as $1 via "--" separator

### Critical Gotchas

- **ID collisions in project.pbxproj**: When generating 24-char hex IDs, ensure they don't collide with existing IDs. Check the file first! Previous collisions caused "project is damaged" errors.
- **drawingGroup() + vibrancy**: Never wrap the outer NotchRootView container in drawingGroup(). It composites everything into an offscreen Metal buffer, breaking NSVisualEffectView's behind-window blending.
- **SourceKit noise**: Single-file swiftc diagnostics can give false errors. Always verify with multi-file swiftc -typecheck including all dependent files.

## Your Task

1. Read the PRD at `prd.json` (in the same directory as this file)
2. Read the progress log at `progress.txt` (check Codebase Patterns section first)
3. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
4. Pick the **highest priority** user story where `passes: false`
5. Implement that single user story
6. Run quality checks: `swiftc -typecheck` on all modified/created Swift files
7. Update CLAUDE.md files if you discover reusable patterns (see below)
8. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
9. Update the PRD to set `passes: true` for the completed story
10. Append your progress to `progress.txt`

## Adding Files to Xcode Project

When creating new Swift files, you MUST update `Hoop.xcodeproj/project.pbxproj`:

1. Generate a unique 24-char hex ID for each reference (CHECK for collisions first!)
2. Add `PBXFileReference` entry for the file
3. Add `PBXBuildFile` entry referencing the file reference
4. Add the file reference to the appropriate `PBXGroup` children array
5. Add the build file to `PBXSourcesBuildPhase` files array

If you create a new directory (e.g., `Window/`, `Models/`, `Services/`), also create a corresponding `PBXGroup` and add it to the parent group's children.

## Progress Report Format

APPEND to progress.txt (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
  - Useful context
---
```

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of progress.txt (create it if it doesn't exist).

## Quality Requirements

- ALL commits must pass `swiftc -typecheck` for modified files
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow existing code patterns (SwiftUI + AppKit interop)

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep builds green
- Read the Codebase Patterns section in progress.txt before starting
- This is a native macOS app — no browser testing needed
