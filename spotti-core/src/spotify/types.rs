use serde::Serialize;

/// Simplified playlist summary for library listing
#[derive(Debug, Clone, Serialize)]
pub struct PlaylistSummary {
    pub id: String,
    pub name: String,
    pub owner: String,
    pub track_count: u32,
    pub image_url: Option<String>,
}

/// Simplified album summary for library/search
#[derive(Debug, Clone, Serialize)]
pub struct AlbumSummary {
    pub id: String,
    pub name: String,
    pub artist: String,
    pub image_url: Option<String>,
    pub release_year: Option<String>,
    pub track_count: u32,
}

/// Simplified artist summary for library/search
#[derive(Debug, Clone, Serialize)]
pub struct ArtistSummary {
    pub id: String,
    pub name: String,
    pub image_url: Option<String>,
}

/// Track in a playlist or album listing (not the same as player::TrackInfo)
#[derive(Debug, Clone, Serialize)]
pub struct TrackSummary {
    pub id: String,
    pub uri: String,
    pub name: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u32,
    pub image_url: Option<String>,
    pub track_number: Option<u32>,
    pub is_playable: bool,
}

/// Full playlist detail (header + tracks)
#[derive(Debug, Clone, Serialize)]
pub struct PlaylistDetail {
    pub id: String,
    pub name: String,
    pub owner: String,
    pub description: Option<String>,
    pub image_url: Option<String>,
    pub tracks: Vec<TrackSummary>,
    pub total_tracks: u32,
}

/// Full album detail
#[derive(Debug, Clone, Serialize)]
pub struct AlbumDetail {
    pub id: String,
    pub name: String,
    pub artist: String,
    pub image_url: Option<String>,
    pub release_date: Option<String>,
    pub tracks: Vec<TrackSummary>,
    pub total_tracks: u32,
}

/// Full artist detail
#[derive(Debug, Clone, Serialize)]
pub struct ArtistDetail {
    pub id: String,
    pub name: String,
    pub image_url: Option<String>,
    pub follower_count: u32,
    pub albums: Vec<AlbumSummary>,
}

/// Search results grouped by type
#[derive(Debug, Clone, Serialize)]
pub struct SearchResults {
    pub query: String,
    pub tracks: Vec<TrackSummary>,
    pub artists: Vec<ArtistSummary>,
    pub albums: Vec<AlbumSummary>,
    pub playlists: Vec<PlaylistSummary>,
}

/// Library content (user's saved items)
#[derive(Debug, Clone, Serialize)]
pub struct LibraryContent {
    pub playlists: Vec<PlaylistSummary>,
    pub saved_albums: Vec<AlbumSummary>,
    pub saved_tracks: Vec<TrackSummary>,
    pub followed_artists: Vec<ArtistSummary>,
}
