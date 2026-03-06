import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var engine: SpottiEngine
    @EnvironmentObject var router: Router

    @State private var selectedTab = 0

    private let tabs = ["Playlists", "Albums", "Artists", "Liked Songs"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Button(action: { selectedTab = index }) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                selectedTab == index
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            Group {
                switch selectedTab {
                case 0: playlistsTab
                case 1: albumsTab
                case 2: artistsTab
                case 3: likedSongsTab
                default: EmptyView()
                }
            }
        }
        .onAppear {
            engine.fetchLibrary()
        }
    }

    private var playlistsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if let library = engine.libraryContent {
                    ForEach(library.playlists) { playlist in
                        PlaylistRow(playlist: playlist) {
                            router.navigate(to: .playlistDetail(id: playlist.id))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var albumsTab: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                if let library = engine.libraryContent {
                    ForEach(library.savedAlbums) { album in
                        AlbumCard(album: album) {
                            router.navigate(to: .albumDetail(id: album.id))
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var artistsTab: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                if let library = engine.libraryContent {
                    ForEach(library.followedArtists) { artist in
                        ArtistCard(artist: artist) {
                            router.navigate(to: .artistDetail(id: artist.id))
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var likedSongsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if let library = engine.libraryContent {
                    ForEach(library.savedTracks) { track in
                        TrackRow(track: track) {
                            engine.loadTrack(uri: track.uri)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct AlbumCard: View {
    let album: AlbumSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                AsyncImage(url: URL(string: album.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                }
                .frame(minHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(album.name)
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(album.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ArtistCard: View {
    let artist: ArtistSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                AsyncImage(url: URL(string: artist.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(.quaternary)
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())

                Text(artist.name)
                    .font(.callout)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
