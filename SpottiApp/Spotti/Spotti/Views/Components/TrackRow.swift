import SwiftUI

struct TrackRow: View {
    let track: TrackSummary
    let trackNumber: Int?
    let action: () -> Void
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @State private var isHovered = false

    init(track: TrackSummary, trackNumber: Int? = nil, action: @escaping () -> Void) {
        self.track = track
        self.trackNumber = trackNumber
        self.action = action
    }

    private var isCurrentTrack: Bool {
        guard let current = engine.currentTrack else { return false }
        if let currentUri = current.uri {
            return track.uri == currentUri
        }
        // Fallback: match bare ID against both id and uri suffix
        let currentId = current.id
        return track.id == currentId
            || track.uri == currentId
            || track.uri.hasSuffix(":\(currentId)")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let number = trackNumber {
                    Group {
                        if isCurrentTrack && engine.isPlaying {
                            EqualizerBars(color: theme.effectiveAccentColor)
                                .frame(width: 16, height: 12)
                        } else {
                            Text("\(number)")
                                .font(.caption)
                                .foregroundStyle(isCurrentTrack ? theme.effectiveAccentColor : .secondary)
                        }
                    }
                    .frame(width: 28, alignment: .trailing)
                    .monospacedDigit()
                }

                AsyncImage(url: track.imageUrl.flatMap(URL.init)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.body)
                        .foregroundStyle(isCurrentTrack ? theme.effectiveAccentColor : .primary)
                        .fontWeight(isCurrentTrack ? .semibold : .regular)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if trackNumber == nil && isCurrentTrack && engine.isPlaying {
                    EqualizerBars(color: theme.effectiveAccentColor)
                        .frame(width: 16, height: 12)
                }

                Text(formatDuration(track.durationMs))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isCurrentTrack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.effectiveAccentColor.opacity(0.15))
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.08))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrentTrack)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .opacity(track.isPlayable ? 1.0 : 0.45)
        .allowsHitTesting(track.isPlayable)
    }
}

struct ArtistRow: View {
    let artist: ArtistSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: artist.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(.quaternary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                Text(artist.name)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }
}

struct AlbumRow: View {
    let album: AlbumSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: album.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(album.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }
}

struct PlaylistRow: View {
    let playlist: PlaylistSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: playlist.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                }
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.body)
                        .lineLimit(1)
                    Text("\(playlist.trackCount) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
    }
}

func formatDuration(_ ms: UInt32) -> String {
    let totalSeconds = ms / 1000
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return "\(minutes):\(String(format: "%02d", seconds))"
}
