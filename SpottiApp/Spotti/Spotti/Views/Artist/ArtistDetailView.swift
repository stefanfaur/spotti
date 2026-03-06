import SwiftUI

struct ArtistDetailView: View {
    let artistId: String
    @EnvironmentObject var engine: SpottiEngine
    @EnvironmentObject var router: Router

    var body: some View {
        ScrollView {
            if let artist = engine.currentArtist, artist.id == artistId {
                VStack(alignment: .leading, spacing: 20) {
                    artistHeader(artist)
                    albumsSection(artist)
                }
            } else {
                ProgressView("Loading artist...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            engine.fetchArtist(id: artistId)
        }
    }

    @ViewBuilder
    private func artistHeader(_ artist: ArtistDetail) -> some View {
        HStack(spacing: 20) {
            AsyncImage(url: URL(string: artist.imageUrl ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 160, height: 160)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 8) {
                Text("Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(artist.name)
                    .font(.largeTitle.bold())
                Text("\(artist.followerCount) followers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private func albumsSection(_ artist: ArtistDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Albums")
                .font(.title2.bold())
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(artist.albums) { album in
                    AlbumCard(album: album) {
                        router.navigate(to: .albumDetail(id: album.id))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
