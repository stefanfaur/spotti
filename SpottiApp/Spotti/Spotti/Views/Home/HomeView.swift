import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var router: Router

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

                // Smart Mix card
                smartMixSection

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
                                    HomeAlbumCard(album: album) {
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
    private var smartMixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Made for You")

            Button {
                engine.smartMix()
                router.navigate(to: .radioQueue)
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Mix")
                            .font(.headline)
                        Text("A personalized mix based on your recent listening")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if engine.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
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
    @EnvironmentObject private var theme: ThemeEngine
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: playlist.imageUrl.flatMap(URL.init)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(.rect(cornerRadius: 8))
                    .rotation3DEffect(
                        .degrees(isHovered ? 3 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )

                    if isHovered {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassEffect(
                                .regular.tint(theme.effectiveAccentColor).interactive(),
                                in: .circle
                            )
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(playlist.name)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(playlist.owner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct HomeAlbumCard: View {
    let album: AlbumSummary
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeEngine
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: album.imageUrl ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                    }
                    .frame(width: 160, height: 160)
                    .clipShape(.rect(cornerRadius: 8))
                    .rotation3DEffect(
                        .degrees(isHovered ? 3 : 0),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )

                    if isHovered {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .glassEffect(
                                .regular.tint(theme.effectiveAccentColor).interactive(),
                                in: .circle
                            )
                            .padding(8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(album.name)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(album.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
