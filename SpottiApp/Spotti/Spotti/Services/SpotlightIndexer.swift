import CoreSpotlight
import UniformTypeIdentifiers

class SpotlightIndexer {
    static let shared = SpotlightIndexer()

    private let indexName = "SpottiLibrary"
    private lazy var index = CSSearchableIndex(name: indexName)

    private init() {}

    /// Index playlists from library content.
    func indexPlaylists(_ playlists: [PlaylistSummary]) {
        let items = playlists.map { playlist -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.title = playlist.name
            attributes.contentDescription = "Playlist \u{2022} \(playlist.trackCount) tracks"
            attributes.displayName = playlist.name

            return CSSearchableItem(
                uniqueIdentifier: "playlist:\(playlist.id)",
                domainIdentifier: "com.spotti.playlists",
                attributeSet: attributes
            )
        }

        index.indexSearchableItems(items) { error in
            if let error {
                print("Spotlight indexing error (playlists): \(error)")
            }
        }
    }

    /// Index saved tracks.
    func indexTracks(_ tracks: [TrackSummary]) {
        // Index in batches of 100 to avoid memory spikes
        let batchSize = 100
        for batch in stride(from: 0, to: tracks.count, by: batchSize) {
            let end = min(batch + batchSize, tracks.count)
            let slice = tracks[batch..<end]

            let items = slice.map { track -> CSSearchableItem in
                let attributes = CSSearchableItemAttributeSet(contentType: .audio)
                attributes.title = track.name
                attributes.artist = track.artist
                attributes.album = track.album
                attributes.contentDescription = "\(track.artist) \u{2022} \(track.album)"
                attributes.displayName = track.name

                return CSSearchableItem(
                    uniqueIdentifier: "track:\(track.id)",
                    domainIdentifier: "com.spotti.tracks",
                    attributeSet: attributes
                )
            }

            index.indexSearchableItems(items) { error in
                if let error {
                    print("Spotlight indexing error (tracks): \(error)")
                }
            }
        }
    }

    /// Remove all Spotti items from Spotlight.
    func deindexAll() {
        index.deleteAllSearchableItems { error in
            if let error {
                print("Spotlight deindex error: \(error)")
            }
        }
    }
}
