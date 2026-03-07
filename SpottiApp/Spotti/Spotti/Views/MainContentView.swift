import SwiftUI

struct MainContentView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var engine: SpottiEngine

    var body: some View {
        VStack(spacing: 0) {
            if router.canGoBack {
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            router.goBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .padding(.vertical, 4)

                    Spacer()
                }
            }

            Group {
                switch router.destination {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .library:
                    LibraryView()
                case .playlistDetail(let id):
                    PlaylistDetailView(playlistId: id)
                        .id(id)
                case .albumDetail(let id):
                    AlbumDetailView(albumId: id)
                        .id(id)
                case .artistDetail(let id):
                    ArtistDetailView(artistId: id)
                        .id(id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .offset(y: 8)))
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: router.destination)
        }
    }
}
