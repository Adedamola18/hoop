import SwiftUI

struct NotchRootView: View {
    let state: NotchState
    let mediaService: MediaService
    let hudService: HUDService
    let contextService: ContextService

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

    private var isActive: Bool {
        isExpanded || isHUD
    }

    /// Whether the media widget should be shown in expanded state.
    /// Shows if: media is active AND (context hints media OR context switching disabled).
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
                // Vibrancy layer (expanded/hud) — frosted glass
                VisualEffectView(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    isActive: isActive
                )
                .clipShape(shape)
                .opacity(isActive ? 1 : 0)

                // Opaque black layer (collapsed) — matches hardware notch
                shape
                    .fill(.black)
                    .opacity(isActive ? 0 : 1)

                // Content overlay
                if isHUD {
                    HUDOverlayView(hudService: hudService)
                        .transition(.opacity)
                } else if isExpanded && shouldShowMediaWidget {
                    MediaPlayerWidget(mediaService: mediaService)
                        .transition(.opacity)
                } else if !isExpanded && hasActiveMedia {
                    CollapsedMediaIndicator(
                        mediaService: mediaService,
                        collapsedSize: state.collapsedSize
                    )
                    .transition(.opacity)
                } else {
                    Text("Hoop")
                        .font(isActive ? .title3 : .caption)
                        .foregroundStyle(.white)
                }
            }
            .frame(
                width: isActive ? geo.size.width : state.collapsedSize.width,
                height: isActive ? geo.size.height : state.collapsedSize.height
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isHUD)
    }
}
