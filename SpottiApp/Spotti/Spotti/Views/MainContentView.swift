import SwiftUI

struct MainContentView: View {
    @EnvironmentObject var engine: SpottiEngine
    @State private var trackUri = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Spotti")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Phase 1 -- Enter a Spotify track URI to play")
                .foregroundStyle(.secondary)

            HStack {
                TextField("spotify:track:...", text: $trackUri)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)

                Button("Play") {
                    guard !trackUri.isEmpty else { return }
                    engine.loadTrack(uri: trackUri)
                }
                .buttonStyle(.borderedProminent)
            }

            if let track = engine.currentTrack {
                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                    Text(track.album)
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .padding(.top, 20)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Test Tracks")
                    .font(.headline)

                ForEach(testTracks, id: \.uri) { track in
                    Button {
                        engine.loadTrack(uri: track.uri)
                    } label: {
                        Text("\(track.name) -- \(track.artist)")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TestTrack: Identifiable {
    let uri: String
    let name: String
    let artist: String
    var id: String { uri }
}

private let testTracks = [
    TestTrack(uri: "spotify:track:4uLU6hMCjMI75M1A2tKUQC", name: "Never Gonna Give You Up", artist: "Rick Astley"),
    TestTrack(uri: "spotify:track:3n3Ppam7vgaVa1iaRUc9Lp", name: "Mr. Brightside", artist: "The Killers"),
    TestTrack(uri: "spotify:track:7qiZfU4dY1lWllzX7mPBI3", name: "Shape of You", artist: "Ed Sheeran"),
]
