import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var engine: SpottiEngine

    private var selectedNavItem: SidebarNavItem? {
        switch router.destination {
        case .home: return .home
        case .search: return .search
        case .library: return .library
        default: return nil
        }
    }

    enum SidebarNavItem: String, CaseIterable {
        case home = "Home"
        case search = "Search"
        case library = "Library"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SidebarNavItem.allCases, id: \.self) { item in
                Button {
                    switch item {
                    case .home: router.navigate(to: .home)
                    case .search: router.navigate(to: .search)
                    case .library: router.navigate(to: .library)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: item))
                            .frame(width: 20)
                        Text(item.rawValue)
                            .fontWeight(selectedNavItem == item ? .semibold : .regular)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selectedNavItem == item
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.vertical, 8)

            Text("YOUR PLAYLISTS")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            if let library = engine.libraryContent {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(library.playlists) { playlist in
                            Button(action: {
                                router.navigate(to: .playlistDetail(id: playlist.id))
                            }) {
                                HStack(spacing: 8) {
                                    AsyncImage(url: URL(string: playlist.imageUrl ?? "")) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text(playlist.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("Loading playlists...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }

            Spacer()
        }
        .padding(.top, 48)
        .onAppear {
            if engine.libraryContent == nil {
                engine.fetchLibrary()
            }
        }
    }

    private func iconName(for item: SidebarNavItem) -> String {
        switch item {
        case .home: "house"
        case .search: "magnifyingglass"
        case .library: "books.vertical"
        }
    }
}
