import SwiftUI
import AppKit

struct MediaPlayerWidget: View {
    let mediaService: MediaService
    /// Height of the hardware notch area — content starts below this.
    var notchHeight: CGFloat = 0

    private var info: NowPlayingInfo { mediaService.nowPlaying }

    private var isActive: Bool {
        info.playbackState == .playing || info.playbackState == .paused
    }

    private var progressFraction: Double {
        guard let elapsed = info.elapsedTime, let duration = info.duration, duration > 0 else {
            return 0
        }
        return min(max(elapsed / duration, 0), 1)
    }

    var body: some View {
        if isActive {
            VStack(spacing: 0) {
                // Spacer for notch area
                Color.clear
                    .frame(height: notchHeight)

                // Main content below the notch
                HStack(spacing: 14) {
                    // Album art
                    albumArtView
                        .frame(width: 100, height: 100)

                    VStack(alignment: .leading, spacing: 8) {
                        // Track info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.title ?? "Unknown Track")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(info.artist ?? "Unknown Artist")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)

                            // Album/playlist name for Apple Music & Spotify
                            if info.isRichMediaApp, let album = info.albumName, !album.isEmpty {
                                Text(album)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .lineLimit(1)
                            }
                        }

                        // Progress bar
                        progressBar

                        // Playback controls
                        HStack(spacing: 28) {
                            Button(action: mediaService.previousTrack) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Button(action: mediaService.playPause) {
                                Image(systemName: info.playbackState == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white)
                            }

                            Button(action: mediaService.nextTrack) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private var albumArtView: some View {
        if let art = info.albumArt {
            Image(nsImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.08))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.3))
                }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))

                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: geo.size.width * progressFraction)
            }
        }
        .frame(height: 3)
    }
}
