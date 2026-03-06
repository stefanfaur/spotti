import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String
    @EnvironmentObject var engine: SpottiEngine

    var body: some View {
        ScrollView {
            if let playlist = engine.currentPlaylist, playlist.id == playlistId {
                VStack(alignment: .leading, spacing: 0) {
                    playlistHeader(playlist)
                    Divider().padding(.horizontal)
                    trackList(playlist)
                }
            } else {
                ProgressView("Loading playlist...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            engine.fetchPlaylist(id: playlistId)
        }
    }

    @ViewBuilder
    private func playlistHeader(_ playlist: PlaylistDetail) -> some View {
        HStack(alignment: .top, spacing: 20) {
            AsyncImage(url: URL(string: playlist.imageUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(playlist.name)
                    .font(.largeTitle.bold())
                if let desc = playlist.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Text("\(playlist.owner) \u{2022} \(playlist.totalTracks) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: { playAll(playlist) }) {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { shufflePlay(playlist) }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func trackList(_ playlist: PlaylistDetail) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                        .monospacedDigit()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.body)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(formatDuration(track.durationMs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    playFromIndex(playlist, index: index)
                }
            }
        }
    }

    private func playAll(_ playlist: PlaylistDetail) {
        let uris = playlist.tracks.map(\.uri)
        engine.loadContext(uris: uris, index: 0)
    }

    private func shufflePlay(_ playlist: PlaylistDetail) {
        engine.setShuffle(true)
        let uris = playlist.tracks.map(\.uri)
        engine.loadContext(uris: uris, index: 0)
    }

    private func playFromIndex(_ playlist: PlaylistDetail, index: Int) {
        let uris = playlist.tracks.map(\.uri)
        engine.loadContext(uris: uris, index: UInt32(index))
    }
}
