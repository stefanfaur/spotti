import SwiftUI

struct LikedSongsView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    private var tracks: [TrackSummary] {
        engine.libraryContent?.savedTracks ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().padding(.horizontal)
                trackList
            }
        }
        .onAppear {
            if engine.libraryContent == nil {
                engine.fetchLibrary()
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            ZStack {
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            }
            .frame(width: 200, height: 200)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Collection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("Liked Songs")
                    .font(.largeTitle.bold())
                Text("\(tracks.count) songs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: playAll) {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.glassProminent)

                    Button(action: shufflePlay) {
                        Label("Shuffle", systemImage: "shuffle")
                    }
                    .buttonStyle(.glass)
                }
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
    private var trackList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track, trackNumber: index + 1) {
                    playFromIndex(index)
                }
                .padding(.horizontal)
            }
        }
    }

    private func playAll() {
        let uris = tracks.map(\.uri)
        guard !uris.isEmpty else { return }
        engine.loadContext(uris: uris, index: 0)
    }

    private func shufflePlay() {
        let uris = tracks.map(\.uri)
        guard !uris.isEmpty else { return }
        engine.setShuffle(true)
        engine.loadContext(uris: uris, index: 0)
    }

    private func playFromIndex(_ index: Int) {
        let uris = tracks.map(\.uri)
        engine.loadContext(uris: uris, index: UInt32(index))
    }
}
