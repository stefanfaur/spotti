import SwiftUI

struct RadioQueueView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                radioHeader
                Divider().padding(.horizontal)
                trackList
            }
        }
    }

    @ViewBuilder
    private var radioHeader: some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.effectiveAccentColor.opacity(0.15))
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 64))
                    .foregroundStyle(theme.effectiveAccentColor)
            }
            .frame(width: 200, height: 200)

            VStack(alignment: .leading, spacing: 8) {
                Text("Radio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(engine.radioName)
                    .font(.largeTitle.bold())
                Text("\(engine.radioUris.count) tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: { engine.loadContext(uris: engine.radioUris, index: 0) }) {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.glassProminent)

                    Button(action: {
                        engine.setShuffle(true)
                        engine.loadContext(uris: engine.radioUris, index: 0)
                    }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.glass)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding()
        .background(alignment: .top) {
            LinearGradient(
                colors: [theme.effectiveAccentColor.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var trackList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(engine.radioTracks.enumerated()), id: \.offset) { index, track in
                RadioTrackRow(index: index + 1, track: track) {
                    engine.loadContext(uris: engine.radioUris, index: UInt32(index))
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct RadioTrackRow: View {
    let index: Int
    let track: SpottiTrackInfo
    let action: () -> Void
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @State private var isHovered = false

    private var isCurrentTrack: Bool {
        if let uri = track.uri { return engine.currentTrack?.uri == uri }
        return engine.currentTrack?.id == track.id
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    if isCurrentTrack && engine.isPlaying {
                        EqualizerBars(color: theme.effectiveAccentColor)
                            .frame(width: 16, height: 12)
                    } else {
                        Text("\(index)")
                            .font(.caption)
                            .foregroundStyle(isCurrentTrack ? theme.effectiveAccentColor : .secondary)
                    }
                }
                .frame(width: 28, alignment: .trailing)
                .monospacedDigit()

                AsyncImage(url: URL(string: track.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .foregroundStyle(isCurrentTrack ? theme.effectiveAccentColor : .primary)
                        .fontWeight(isCurrentTrack ? .semibold : .regular)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isCurrentTrack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.effectiveAccentColor.opacity(0.12))
                    }
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6).fill(.ultraThinMaterial)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrentTrack)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
