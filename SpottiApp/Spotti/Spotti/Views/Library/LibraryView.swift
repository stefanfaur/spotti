import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var theme: ThemeEngine

    @State private var selectedTab = 0

    private let tabs = ["Playlists", "Albums", "Artists", "Liked Songs"]

    var body: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: theme.glassSpacing) {
                HStack(spacing: 8) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                        tabButton(index: index, label: title)
                    }
                    Spacer()
                }
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

    private func tabButton(index: Int, label: String) -> some View {
        Button { selectedTab = index } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(selectedTab == index ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .glassEffect(
                    selectedTab == index
                        ? .regular.tint(theme.effectiveAccentColor).interactive()
                        : .regular.interactive(),
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
    }

    private var playlistsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if let library = engine.libraryContent {
                    ForEach(library.playlists) { playlist in
                        PlaylistRow(playlist: playlist) {
                            router.navigate(to: .playlistDetail(id: playlist.id))
                        }
                        .hoverHighlight()
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
                        .hoverScale()
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
                        .hoverScale()
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
                .clipShape(.rect(cornerRadius: 8))

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
