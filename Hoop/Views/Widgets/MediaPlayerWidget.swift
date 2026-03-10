import SwiftUI
import AppKit

struct MediaPlayerWidget: View {
    let mediaService: MediaService

    private var info: NowPlayingInfo { mediaService.nowPlaying }

    private var isActive: Bool {
        info.playbackState == .playing || info.playbackState == .paused
    }

    /// Use cached icon from MediaService instead of expensive NSWorkspace lookup per render.
    private var sourceAppIcon: NSImage? {
        mediaService.sourceAppIcon
    }

    private var progressFraction: Double {
        guard let elapsed = info.elapsedTime, let duration = info.duration, duration > 0 else {
            return 0
        }
        return min(max(elapsed / duration, 0), 1)
    }

    var body: some View {
        if isActive {
            HStack(spacing: 16) {
                // Album art
                albumArtView
                    .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 6) {
                    // Source app icon + track info
                    HStack(spacing: 6) {
                        if let icon = sourceAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                                .cornerRadius(3)
                        }

                        Text(info.title ?? "Unknown Track")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Text(info.artist ?? "Unknown Artist")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)

                    // Progress bar
                    progressBar

                    // Playback controls
                    HStack(spacing: 20) {
                        Button(action: mediaService.previousTrack) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                        }

                        Button(action: mediaService.playPause) {
                            Image(systemName: info.playbackState == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                        }

                        Button(action: mediaService.nextTrack) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var albumArtView: some View {
        if let art = info.albumArt {
            Image(nsImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.1))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.4))
                }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))

                Capsule()
                    .fill(.white.opacity(0.8))
                    .frame(width: geo.size.width * progressFraction)
            }
        }
        .frame(height: 3)
        .drawingGroup()
    }
}
