import SwiftUI

struct SidebarView: View {
    @State private var selectedItem: SidebarItem = .home

    enum SidebarItem: String, CaseIterable {
        case home = "Home"
        case search = "Search"
        case library = "Library"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SidebarItem.allCases, id: \.self) { item in
                Button {
                    selectedItem = item
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: iconName(for: item))
                            .frame(width: 20)
                        Text(item.rawValue)
                            .fontWeight(selectedItem == item ? .semibold : .regular)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        selectedItem == item
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

            Text("Playlists will appear here")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.top, 48)
    }

    private func iconName(for item: SidebarItem) -> String {
        switch item {
        case .home: "house"
        case .search: "magnifyingglass"
        case .library: "books.vertical"
        }
    }
}
