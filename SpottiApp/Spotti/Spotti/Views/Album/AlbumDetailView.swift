import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        ScrollView {
            if let album = engine.currentAlbum, album.id == albumId {
                VStack(alignment: .leading, spacing: 0) {
                    albumHeader(album)
                    Divider().padding(.horizontal)
                    trackList(album)
                }
            } else {
                ProgressView("Loading album...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            engine.fetchAlbum(id: albumId)
        }
    }

    @ViewBuilder
    private func albumHeader(_ album: AlbumDetail) -> some View {
        HStack(alignment: .top, spacing: 20) {
            AsyncImage(url: URL(string: album.imageUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
            }
            .frame(width: 200, height: 200)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Album")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(album.name)
                    .font(.largeTitle.bold())
                Text(album.artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if let date = album.releaseDate {
                    Text(date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(album.totalTracks) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(action: { playAll(album) }) {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.glassProminent)
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
    private func trackList(_ album: AlbumDetail) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track, trackNumber: Int(track.trackNumber ?? UInt32(index + 1))) {
                    let uris = album.tracks.map(\.uri)
                    engine.loadContext(uris: uris, index: UInt32(index))
                }
                .padding(.horizontal)
            }
        }
    }

    private func playAll(_ album: AlbumDetail) {
        let uris = album.tracks.map(\.uri)
        engine.loadContext(uris: uris, index: 0)
    }
}
