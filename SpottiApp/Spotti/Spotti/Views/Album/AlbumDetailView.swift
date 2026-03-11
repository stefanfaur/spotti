import SwiftUI

struct AlbumDetailView: View {
    let albumId: String
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var theme: ThemeEngine
    @State private var wikiExpanded = false

    var body: some View {
        ScrollView {
            if let album = engine.currentAlbum, album.id == albumId {
                VStack(alignment: .leading, spacing: 0) {
                    albumHeader(album)
                    Divider().padding(.horizontal)
                    trackList(album)
                    aboutSection(album)
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

    @ViewBuilder
    private func aboutSection(_ album: AlbumDetail) -> some View {
        if album.wiki != nil || !album.lastfmTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider().padding(.horizontal)

                if !album.lastfmTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(album.lastfmTags, id: \.self) { tag in
                                Button(tag) {
                                    engine.clearRadio()
                                    engine.playTagRadio(tag: tag)
                                    router.navigate(to: .radioQueue)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                                .buttonStyle(.plain)
                                .disabled(engine.loadingTagRadio != nil)
                                .overlay {
                                    if engine.loadingTagRadio == tag {
                                        Capsule()
                                            .fill(.quaternary)
                                            .overlay {
                                                ProgressView()
                                                    .controlSize(.mini)
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let wiki = album.wiki {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("About")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        Text(wiki)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(wikiExpanded ? nil : 3)
                            .padding(.horizontal)

                        Button(wikiExpanded ? "Show less" : "Show more") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                wikiExpanded.toggle()
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
    }
}
