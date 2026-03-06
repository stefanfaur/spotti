import SwiftUI

struct HomeView: View {
    @EnvironmentObject var engine: SpottiEngine
    @EnvironmentObject var router: Router

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(greeting)
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .padding(.top)

                if let library = engine.libraryContent {
                    if !library.playlists.isEmpty {
                        sectionHeader("Your Playlists")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(library.playlists.prefix(10)) { playlist in
                                    PlaylistCard(playlist: playlist) {
                                        router.navigate(to: .playlistDetail(id: playlist.id))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    if !library.savedAlbums.isEmpty {
                        sectionHeader("Saved Albums")
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(library.savedAlbums.prefix(10)) { album in
                                    AlbumCard(album: album) {
                                        router.navigate(to: .albumDetail(id: album.id))
                                    }
                                    .frame(width: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .onAppear {
            if engine.libraryContent == nil {
                engine.fetchLibrary()
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title2.bold())
            .padding(.horizontal)
    }
}

struct PlaylistCard: View {
    let playlist: PlaylistSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: URL(string: playlist.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(playlist.name)
                    .font(.callout.bold())
                    .lineLimit(2)
                Text(playlist.owner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
    }
}
