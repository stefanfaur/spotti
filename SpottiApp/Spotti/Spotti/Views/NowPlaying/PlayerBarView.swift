import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject var engine: SpottiEngine

    var body: some View {
        HStack(spacing: 16) {
            trackInfoSection
            Spacer()
            playbackControls
            Spacer()
            Color.clear.frame(width: 250) // Placeholder for volume/device (Phase 2+)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Sections

    private var trackInfoSection: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 56, height: 56)

            if let track = engine.currentTrack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Not Playing")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 250, alignment: .leading)
    }

    private var playbackControls: some View {
        VStack(spacing: 4) {
            HStack(spacing: 24) {
                Button { engine.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button { engine.togglePlayPause() } label: {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)

                Button { engine.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if let track = engine.currentTrack {
                seekBar(duration: track.durationMs)
            }
        }
        .frame(maxWidth: 400)
    }

    private func seekBar(duration: UInt32) -> some View {
        HStack(spacing: 8) {
            Text(formatTime(engine.positionMs))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Slider(
                value: Binding(
                    get: { Double(engine.positionMs) },
                    set: { engine.seek(to: UInt32($0)) }
                ),
                in: 0...max(Double(duration), 1)
            )

            Text(formatTime(duration))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func formatTime(_ ms: UInt32) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
