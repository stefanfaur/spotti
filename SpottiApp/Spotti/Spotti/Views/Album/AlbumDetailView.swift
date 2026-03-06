import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    @EnvironmentObject var engine: SpottiEngine

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
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func trackList(_ album: AlbumDetail) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 12) {
                    Text("\(track.trackNumber ?? UInt32(index + 1))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                        .monospacedDigit()

                    Text(track.name)
                        .font(.body)
                        .lineLimit(1)

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
                    let uris = album.tracks.map(\.uri)
                    engine.loadContext(uris: uris, index: UInt32(index))
                }
            }
        }
    }

    private func playAll(_ album: AlbumDetail) {
        let uris = album.tracks.map(\.uri)
        engine.loadContext(uris: uris, index: 0)
    }
}
