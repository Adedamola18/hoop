import SwiftUI

struct NotchRootView: View {
    let state: NotchState
    let mediaService: MediaService
    let hudService: HUDService
    let contextService: ContextService
    let dropActionService: DropActionService
    let batteryService: BatteryService
    let privacyService: PrivacyService

    private var hasPrivacyIndicators: Bool {
        privacyService.isCameraActive || privacyService.isMicrophoneActive
    }

    private var isExpanded: Bool {
        state.phase == .expanding || state.phase == .expanded
    }

    private var isHUD: Bool {
        state.phase == .hud
    }

    private var hasActiveMedia: Bool {
        mediaService.nowPlaying.playbackState == .playing ||
        mediaService.nowPlaying.playbackState == .paused
    }

    private var isTray: Bool {
        state.phase == .tray
    }

    private var isActive: Bool {
        isExpanded || isHUD || isTray
    }

    /// Whether the media widget should be shown in expanded state.
    private var shouldShowMediaWidget: Bool {
        guard hasActiveMedia else { return false }
        if !contextService.isEnabled { return true }
        return contextService.widgetHint == .media || hasActiveMedia
    }

    var body: some View {
        GeometryReader { geo in
            let shape = NotchShape(
                cornerRadius: isActive ? 20 : 10,
                notchWidth: state.collapsedSize.width,
                notchDepth: isActive ? state.collapsedSize.height : 0,
                hasNotch: state.screenHasNotch
            )

            ZStack {
                // Theme-based background
                switch state.themeMode {
                case .solidDark:
                    shape.fill(.black)
                case .translucentDark:
                    ZStack {
                        shape.fill(.black.opacity(0.5))
                        VisualEffectView(
                            material: .popover,
                            blendingMode: .behindWindow,
                            isActive: true
                        )
                        .clipShape(shape)
                    }
                case .liquidGlass:
                    ZStack {
                        VisualEffectView(
                            material: .hudWindow,
                            blendingMode: .behindWindow,
                            isActive: true
                        )
                        .clipShape(shape)
                        shape.fill(.white.opacity(0.06))
                    }
                }

                // Content area — padded below the notch cutout
                Group {
                    if isTray, case .idle = dropActionService.dropPhase {
                        DropZoneView()
                            .transition(.opacity)
                    } else if isTray {
                        DropActionSelectionView(dropActionService: dropActionService)
                            .transition(.opacity)
                    } else if isHUD {
                        HUDOverlayView(hudService: hudService)
                            .transition(.opacity)
                    } else if isExpanded && shouldShowMediaWidget {
                        MediaPlayerWidget(
                            mediaService: mediaService,
                            notchHeight: state.collapsedSize.height
                        )
                        .transition(.opacity)
                    } else if !isExpanded && hasActiveMedia {
                        ZStack {
                            CollapsedMediaIndicator(
                                mediaService: mediaService,
                                collapsedSize: state.collapsedSize
                            )
                            collapsedIndicators
                        }
                        .transition(.opacity)
                    } else if !isExpanded && !hasActiveMedia {
                        collapsedIndicators
                            .transition(.opacity)
                    } else if isExpanded {
                        Text("Hoop")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, state.collapsedSize.height)
                    }
                }
                .clipShape(shape)
            }
            .frame(
                width: isActive ? geo.size.width : state.collapsedSize.width,
                height: isActive ? geo.size.height : state.collapsedSize.height
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isHUD)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isTray)
    }

    /// Collapsed notch indicators: privacy dots (left) + battery (right)
    @ViewBuilder
    private var collapsedIndicators: some View {
        HStack {
            if hasPrivacyIndicators {
                PrivacyIndicatorView(privacyService: privacyService)
                    .padding(.leading, 12)
            }
            Spacer()
            if batteryService.battery.isValid {
                BatteryIndicator(batteryService: batteryService)
                    .padding(.trailing, 12)
            }
        }
    }
}
