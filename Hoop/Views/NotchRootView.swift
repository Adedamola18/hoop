import SwiftUI

struct NotchRootView: View {
    let state: NotchState
    let mediaService: MediaService
    let hudService: HUDService
    let contextService: ContextService
    let dropActionService: DropActionService
    let batteryService: BatteryService
    let privacyService: PrivacyService
    let focusService: FocusService
    let widgetRegistry: WidgetRegistry
    let callService: CallService
    let airDropService: AirDropService
    let startupAnimator: StartupAnimator
    let alertEngine: AlertEngine
    let securityGate: SecurityGate

    private var hasCollapsedIndicators: Bool {
        privacyService.isCameraActive || privacyService.isMicrophoneActive ||
        privacyService.isScreenRecording || focusService.isActive || batteryService.battery.isValid
    }

    private var isExpanded: Bool {
        state.phase == .expanding || state.phase == .expanded
    }

    private var isHUD: Bool {
        state.phase == .hud
    }

    private var hasActiveMedia: Bool {
        let np = mediaService.nowPlaying
        let hasState = np.playbackState == .playing || np.playbackState == .paused
        // Require actual track data — avoids showing "Unknown Track" on stale/empty states
        return hasState && np.title != nil
    }

    private var isTray: Bool {
        state.phase == .tray
    }

    private var isAlert: Bool {
        state.phase == .alert
    }

    private var isStartup: Bool {
        startupAnimator.phase != .done
    }

    private var isActive: Bool {
        isExpanded || isHUD || isTray || isAlert || isStartup
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
                    if isStartup {
                        startupOverlay
                            .transition(.opacity)
                    } else if isTray {
                        FileDropTrayView(dropActionService: dropActionService)
                            .transition(.opacity)
                    } else if isHUD {
                        HUDOverlayView(hudService: hudService)
                            .transition(.opacity)
                    } else if isAlert, let alert = state.activeAlert {
                        if securityGate.isProtected("tradingAlerts") && !securityGate.isUnlocked {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                Text("Trading Alert -- Unlock to view")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                        } else if alert.priority == .high {
                            AlertDetailView(
                                alert: alert,
                                onDismiss: { alertEngine.dismissCurrentAlert() },
                                onSnooze: { alertEngine.snoozeCurrentAlert() },
                                onOpenInBrowser: { openAlertInBrowser(alert) }
                            )
                            .transition(.opacity)
                        } else {
                            AlertToastView(alert: alert, onDismiss: { alertEngine.dismissCurrentAlert() })
                                .transition(.opacity)
                        }
                    } else if callService.isCallActive {
                        IncomingCallView(callService: callService)
                            .transition(.opacity)
                    } else if airDropService.isTransferActive && !isExpanded {
                        AirDropIndicatorView(airDropService: airDropService)
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
                            CollapsedIndicatorBar(
                                privacyService: privacyService,
                                focusService: focusService,
                                batteryService: batteryService,
                                alertEngine: alertEngine
                            )
                        }
                        .transition(.opacity)
                    } else if !isExpanded && !hasActiveMedia && hasCollapsedIndicators {
                        CollapsedIndicatorBar(
                            privacyService: privacyService,
                            focusService: focusService,
                            batteryService: batteryService,
                            alertEngine: alertEngine
                        )
                        .transition(.opacity)
                    } else if isExpanded {
                        WidgetDrawerView(
                            widgetRegistry: widgetRegistry,
                            notchHeight: state.collapsedSize.height
                        )
                        .transition(.opacity)
                    }
                }
                .clipShape(shape)
                .notchAccentGlow(
                    accent: state.activeAlert?.accentColor,
                    isActive: isAlert
                )
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
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isAlert)
    }

    // MARK: - Startup Overlay

    @ViewBuilder
    private var startupOverlay: some View {
        HoopCalligraphyMark(
            visibleCharacters: startupAnimator.visibleCharacters,
            isExiting: startupAnimator.phase == .pulse
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { startupAnimator.skip() }
    }

    // MARK: - Helpers

    private func openAlertInBrowser(_ alert: TradingAlert) {
        let urlString: String
        switch alert.signal.sourceId {
        case "binance":
            let symbol = alert.signal.symbol.lowercased()
            urlString = "https://www.binance.com/en/trade/\(symbol)"
        case "bybit":
            urlString = "https://www.bybit.com/en/trade/spot/\(alert.signal.symbol)"
        case "polymarket":
            urlString = "https://polymarket.com"
        case "kalshi":
            urlString = "https://kalshi.com"
        default:
            return
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Calligraphy Mark

private struct HoopCalligraphyMark: View {
    let visibleCharacters: Int
    let isExiting: Bool

    private static let letters: [Character] = Array("Hoop")

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: -1) {
            ForEach(Array(Self.letters.enumerated()), id: \.offset) { idx, ch in
                InkLetter(
                    character: ch,
                    visible: idx < visibleCharacters
                )
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 4)
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        .opacity(isExiting ? 0 : 1.0)
        .scaleEffect(isExiting ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.9), value: isExiting)
    }
}

/// Renders a single calligraphy letter that "writes in" via a left-to-right
/// gradient mask sweep, so the reveal feels like ink flowing from a pen tip.
private struct InkLetter: View {
    let character: Character
    let visible: Bool

    var body: some View {
        Text(String(character))
            .font(.custom("PlaywriteDESAS-Regular", size: 52))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color.white.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .fixedSize()
            .mask(alignment: .leading) {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: visible ? 0.92 : 0.0),
                        .init(color: .clear, location: visible ? 1.05 : 0.05)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .animation(.easeOut(duration: 0.7), value: visible)
    }
}
