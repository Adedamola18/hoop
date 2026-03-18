import SwiftUI
import AppKit

struct CollapsedMediaIndicator: View {
    let mediaService: MediaService
    let collapsedSize: CGSize

    private var isPlaying: Bool {
        mediaService.nowPlaying.playbackState == .playing
    }

    private var isActive: Bool {
        mediaService.nowPlaying.playbackState == .playing ||
        mediaService.nowPlaying.playbackState == .paused
    }

    var body: some View {
        if isActive {
            HStack(spacing: 0) {
                // Left side: album art peek
                albumArtPeek
                    .padding(.trailing, 4)

                Spacer()
                    .frame(width: collapsedSize.width)

                // Right side: waveform bars
                waveformBars
                    .padding(.leading, 4)
            }
            .frame(height: collapsedSize.height)
        }
    }

    // MARK: - Album Art Peek

    @ViewBuilder
    private var albumArtPeek: some View {
        let size: CGFloat = collapsedSize.height * 0.6

        if let art = mediaService.nowPlaying.albumArt {
            Image(nsImage: art)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(.gray.opacity(0.5))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.white.opacity(0.7))
                }
        }
    }

    // MARK: - Waveform Bars

    @ViewBuilder
    private var waveformBars: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                WaveformShape(date: timeline.date)
                    .frame(width: 20, height: collapsedSize.height * 0.5)
            }
            .drawingGroup()
        } else {
            // Static bars when paused
            WaveformShape(date: nil)
                .frame(width: 20, height: collapsedSize.height * 0.5)
                .drawingGroup()
        }
    }
}

// MARK: - Waveform Shape

private struct WaveformShape: View {
    let date: Date?

    private let barCount = 4
    private let barSpacing: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let barWidth = (geo.size.width - barSpacing * CGFloat(barCount - 1)) / CGFloat(barCount)

            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let height = barHeight(index: index, maxHeight: geo.size.height)
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(.white.opacity(0.8))
                        .frame(width: max(barWidth, 1), height: height)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private func barHeight(index: Int, maxHeight: CGFloat) -> CGFloat {
        guard let date else {
            // Static paused state: staggered low bars
            let staticHeights: [CGFloat] = [0.3, 0.5, 0.4, 0.25]
            let fraction = index < staticHeights.count ? staticHeights[index] : 0.3
            return max(2, maxHeight * fraction)
        }

        let time = date.timeIntervalSinceReferenceDate
        // Each bar oscillates at different frequency/phase for organic look
        let frequencies: [Double] = [2.5, 3.2, 1.8, 2.9]
        let phases: [Double] = [0, 0.8, 1.6, 0.4]
        let freq = index < frequencies.count ? frequencies[index] : 2.0
        let phase = index < phases.count ? phases[index] : 0.0

        let sineValue = sin(time * freq + phase)
        // Map sine [-1, 1] to height fraction [0.15, 0.95]
        let fraction = 0.15 + (sineValue + 1) * 0.4
        return max(2, maxHeight * fraction)
    }
}
