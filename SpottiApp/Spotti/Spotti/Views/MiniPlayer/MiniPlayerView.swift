import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        HStack(spacing: 10) {
            albumArt
            trackInfo
            Spacer(minLength: 4)
            controls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 300, height: 72)
        .background(.ultraThinMaterial)
        .clipShape(.capsule)
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
        .shadow(color: theme.dominantColor.opacity(0.2), radius: 12, y: 2)
    }

    @ViewBuilder
    private var albumArt: some View {
        Group {
            if let track = engine.currentTrack,
               let urlStr = track.imageUrl,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.quaternary)
                }
            } else {
                Circle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(.circle)
        .shadow(color: theme.dominantColor.opacity(0.4), radius: 6, y: 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.currentTrack?.id)
    }

    @ViewBuilder
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let track = engine.currentTrack {
                Text(track.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Not Playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 110, alignment: .leading)
    }

    @ViewBuilder
    private var controls: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 8) {
                Button { engine.togglePlayPause() } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .glassEffect(
                            .regular.tint(theme.accentColor),
                            in: .circle
                        )
                }
                .buttonStyle(.plain)

                Button { engine.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
