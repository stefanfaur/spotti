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
    let isPlayable: Bool

    enum CodingKeys: String, CodingKey {
        case id, uri, name, artist, album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
        case trackNumber = "track_number"
        case isPlayable = "is_playable"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        uri = try c.decode(String.self, forKey: .uri)
        name = try c.decode(String.self, forKey: .name)
        artist = try c.decode(String.self, forKey: .artist)
        album = try c.decode(String.self, forKey: .album)
        durationMs = try c.decode(UInt32.self, forKey: .durationMs)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        trackNumber = try c.decodeIfPresent(UInt32.self, forKey: .trackNumber)
        isPlayable = try c.decodeIfPresent(Bool.self, forKey: .isPlayable) ?? true
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
    let wiki: String?
    let lastfmTags: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, artist, tracks, wiki
        case imageUrl = "image_url"
        case releaseDate = "release_date"
        case totalTracks = "total_tracks"
        case lastfmTags = "lastfm_tags"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        artist = try c.decode(String.self, forKey: .artist)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        releaseDate = try c.decodeIfPresent(String.self, forKey: .releaseDate)
        tracks = try c.decode([TrackSummary].self, forKey: .tracks)
        totalTracks = try c.decode(UInt32.self, forKey: .totalTracks)
        wiki = try c.decodeIfPresent(String.self, forKey: .wiki)
        lastfmTags = (try? c.decode([String].self, forKey: .lastfmTags)) ?? []
    }
}

struct ArtistDetail: Codable {
    let id: String
    let name: String
    let imageUrl: String?
    let followerCount: UInt32
    let albums: [AlbumSummary]
    let bio: String?
    let lastfmTags: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, albums, bio
        case imageUrl = "image_url"
        case followerCount = "follower_count"
        case lastfmTags = "lastfm_tags"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        followerCount = try c.decode(UInt32.self, forKey: .followerCount)
        albums = try c.decode([AlbumSummary].self, forKey: .albums)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        lastfmTags = (try? c.decode([String].self, forKey: .lastfmTags)) ?? []
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
