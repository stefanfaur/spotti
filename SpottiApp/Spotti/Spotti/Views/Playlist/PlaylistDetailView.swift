import SwiftUI

struct PlaylistDetailView: View {
    let playlistId: String
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

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
            .clipShape(.rect(cornerRadius: 8))

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
                    .buttonStyle(.glassProminent)

                    Button(action: { shufflePlay(playlist) }) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.glass)

                    Button(action: { playlistRadio(playlist) }) {
                        Label("Radio", systemImage: "antenna.radiowaves.left.and.right")
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
                colors: [theme.dominantColor.opacity(0.25), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func trackList(_ playlist: PlaylistDetail) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track, trackNumber: index + 1) {
                    playFromIndex(playlist, index: index)
                }
                .padding(.horizontal)
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

    private func playlistRadio(_ playlist: PlaylistDetail) {
        let seeds = playlist.tracks
            .filter { $0.isPlayable }
            .shuffled()
            .prefix(5)
            .map { $0.id }
        engine.playPlaylistRadio(trackIds: Array(seeds))
    }

    private func playFromIndex(_ playlist: PlaylistDetail, index: Int) {
        let uris = playlist.tracks.map(\.uri)
        engine.loadContext(uris: uris, index: UInt32(index))
    }
}
