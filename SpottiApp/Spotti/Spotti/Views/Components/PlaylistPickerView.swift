import SwiftUI

struct PlaylistPickerView: View {
    let onSelect: (String) -> Void   // called with playlistId

    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ADD TO PLAYLIST")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            let playlists = engine.libraryContent?.playlists ?? []
            if playlists.isEmpty {
                Text("No playlists found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(playlists, id: \.id) { playlist in
                            PlaylistPickerRow(playlist: playlist) {
                                onSelect(playlist.id)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 260)
        .padding(.bottom, 10)
    }
}

private struct PlaylistPickerRow: View {
    let playlist: PlaylistSummary
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: playlist.imageUrl ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                }
                .frame(width: 32, height: 32)
                .clipShape(.rect(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 1) {
                    Text(playlist.name)
                        .font(.callout)
                        .lineLimit(1)
                    Text("\(playlist.trackCount) songs")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
    }
}
