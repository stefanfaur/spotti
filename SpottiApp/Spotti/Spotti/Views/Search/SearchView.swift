import SwiftUI
import Combine

struct SearchView: View {
    @EnvironmentObject var engine: SpottiEngine
    @EnvironmentObject var router: Router

    @State private var searchText = ""
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchBar

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
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("What do you want to listen to?", text: $searchText)
                .textFieldStyle(.plain)
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
                Button(action: {
                    searchText = ""
                    engine.searchResults = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
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
