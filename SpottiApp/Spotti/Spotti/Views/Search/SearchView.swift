import SwiftUI
import Combine

struct SearchView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var theme: ThemeEngine

    @State private var searchText = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.top, 12)

            if let results = engine.searchResults, !searchText.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if !results.tracks.isEmpty {
                            searchSection(title: "Songs") {
                                ForEach(results.tracks) { track in
                                    TrackRow(track: track) {
                                        engine.loadTrack(uri: track.uri)
                                    }
                                }
                            }
                        }

                        if !results.artists.isEmpty {
                            searchSection(title: "Artists") {
                                ForEach(results.artists) { artist in
                                    ArtistRow(artist: artist) {
                                        router.navigate(to: .artistDetail(id: artist.id))
                                    }
                                }
                            }
                        }

                        if !results.albums.isEmpty {
                            searchSection(title: "Albums") {
                                ForEach(results.albums) { album in
                                    AlbumRow(album: album) {
                                        router.navigate(to: .albumDetail(id: album.id))
                                    }
                                }
                            }
                        }

                        if !results.playlists.isEmpty {
                            searchSection(title: "Playlists") {
                                ForEach(results.playlists) { playlist in
                                    PlaylistRow(playlist: playlist) {
                                        router.navigate(to: .playlistDetail(id: playlist.id))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else if searchText.isEmpty {
                ContentUnavailableView("Search Spotify", systemImage: "magnifyingglass",
                    description: Text("Find songs, artists, albums, and playlists"))
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search songs, artists, albums...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .onChange(of: searchText) { _, newValue in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        if !newValue.isEmpty {
                            engine.search(query: newValue)
                        } else {
                            engine.searchResults = nil
                        }
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    engine.searchResults = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(
            .regular.tint(theme.accentColor).interactive(),
            in: .capsule
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func searchSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            content()
        }
    }
}
