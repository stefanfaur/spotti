import Foundation

struct PlaylistSummary: Codable, Identifiable {
    let id: String
    let name: String
    let owner: String
    let trackCount: UInt32
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case trackCount = "track_count"
        case imageUrl = "image_url"
    }
}

struct AlbumSummary: Codable, Identifiable {
    let id: String
    let name: String
    let artist: String
    let imageUrl: String?
    let releaseYear: String?
    let trackCount: UInt32

    enum CodingKeys: String, CodingKey {
        case id, name, artist
        case imageUrl = "image_url"
        case releaseYear = "release_year"
        case trackCount = "track_count"
    }
}

struct ArtistSummary: Codable, Identifiable {
    let id: String
    let name: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case imageUrl = "image_url"
    }
}

struct TrackSummary: Codable, Identifiable {
    let id: String
    let uri: String
    let name: String
    let artist: String
    let album: String
    let durationMs: UInt32
    let imageUrl: String?
    let trackNumber: UInt32?

    enum CodingKeys: String, CodingKey {
        case id, uri, name, artist, album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
        case trackNumber = "track_number"
    }
}

struct PlaylistDetail: Codable {
    let id: String
    let name: String
    let owner: String
    let description: String?
    let imageUrl: String?
    let tracks: [TrackSummary]
    let totalTracks: UInt32

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description, tracks
        case imageUrl = "image_url"
        case totalTracks = "total_tracks"
    }
}

struct AlbumDetail: Codable {
    let id: String
    let name: String
    let artist: String
    let imageUrl: String?
    let releaseDate: String?
    let tracks: [TrackSummary]
    let totalTracks: UInt32

    enum CodingKeys: String, CodingKey {
        case id, name, artist, tracks
        case imageUrl = "image_url"
        case releaseDate = "release_date"
        case totalTracks = "total_tracks"
    }
}

struct ArtistDetail: Codable {
    let id: String
    let name: String
    let imageUrl: String?
    let followerCount: UInt32
    let albums: [AlbumSummary]

    enum CodingKeys: String, CodingKey {
        case id, name, albums
        case imageUrl = "image_url"
        case followerCount = "follower_count"
    }
}

struct SearchResults: Codable {
    let query: String
    let tracks: [TrackSummary]
    let artists: [ArtistSummary]
    let albums: [AlbumSummary]
    let playlists: [PlaylistSummary]
}

struct LibraryContent: Codable {
    let playlists: [PlaylistSummary]
    let savedAlbums: [AlbumSummary]
    let savedTracks: [TrackSummary]
    let followedArtists: [ArtistSummary]

    enum CodingKeys: String, CodingKey {
        case playlists
        case savedAlbums = "saved_albums"
        case savedTracks = "saved_tracks"
        case followedArtists = "followed_artists"
    }
}
