import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var engine: SpottiEngine

    var body: some View {
        VStack(spacing: 0) {
            if router.canGoBack {
                HStack {
                    Button(action: { router.goBack() }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 4)
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
                case .albumDetail(let id):
                    AlbumDetailView(albumId: id)
                case .artistDetail(let id):
                    ArtistDetailView(artistId: id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
