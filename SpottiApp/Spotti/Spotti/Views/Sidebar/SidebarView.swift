import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var router: Router
    @Namespace private var sidebarNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SidebarNavItem.allCases) { item in
                    sidebarButton(for: item)
                }
            }
            .padding(.horizontal, 12)

            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Text("YOUR PLAYLISTS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            if let library = engine.libraryContent {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(library.playlists) { playlist in
                            playlistRow(playlist)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            } else {
                Text("Loading playlists...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
            }

            Spacer()
        }
        .padding(.top, 12)
        .frame(width: 240)
        .onAppear {
            if engine.libraryContent == nil {
                engine.fetchLibrary()
            }
        }
    }

    @ViewBuilder
    private func sidebarButton(for item: SidebarNavItem) -> some View {
        let isSelected = isItemSelected(item)

        Button {
            router.navigate(to: item.destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.body)
                    .frame(width: 20)
                Text(item.title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? theme.accentColor.opacity(0.25) : .clear)
        }
        .fontWeight(isSelected ? .semibold : .regular)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    @ViewBuilder
    private func playlistRow(_ playlist: PlaylistSummary) -> some View {
        Button {
            router.navigate(to: .playlistDetail(id: playlist.id))
        } label: {
            HStack(spacing: 10) {
                AsyncImage(url: playlist.imageUrl.flatMap(URL.init)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                }
                .frame(width: 28, height: 28)
                .clipShape(.rect(cornerRadius: 4))

                Text(playlist.name)
                    .font(.callout)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func isItemSelected(_ item: SidebarNavItem) -> Bool {
        switch (item, router.destination) {
        case (.home, .home): true
        case (.search, .search): true
        case (.library, .library): true
        default: false
        }
    }
}

private enum SidebarNavItem: String, CaseIterable, Identifiable {
    case home, search, library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .library: "Library"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .library: "books.vertical"
        }
    }

    var destination: NavigationDestination {
        switch self {
        case .home: .home
        case .search: .search
        case .library: .library
        }
    }
}
