use rspotify::clients::OAuthClient;
use rspotify::AuthCodePkceSpotify;

use super::convert;
use super::types::*;

#[derive(Debug, thiserror::Error)]
pub enum LibraryError {
    #[error("Spotify API error: {0}")]
    ApiError(String),
}

/// Fetch user's playlists (first 50)
pub async fn fetch_playlists(
    client: &AuthCodePkceSpotify,
) -> Result<Vec<PlaylistSummary>, LibraryError> {
    let playlists = client
        .current_user_playlists_manual(Some(50), None)
        .await
        .map_err(|e| LibraryError::ApiError(e.to_string()))?;

    Ok(playlists
        .items
        .iter()
        .map(convert::playlist_to_summary)
        .collect())
}

/// Fetch user's saved albums (first 50)
pub async fn fetch_saved_albums(
    client: &AuthCodePkceSpotify,
) -> Result<Vec<AlbumSummary>, LibraryError> {
    let albums = client
        .current_user_saved_albums_manual(None, Some(50), None)
        .await
        .map_err(|e| LibraryError::ApiError(e.to_string()))?;

    Ok(albums
        .items
        .iter()
        .map(|saved| convert::full_album_to_summary(&saved.album))
        .collect())
}

/// Fetch user's saved tracks (first 50)
pub async fn fetch_saved_tracks(
    client: &AuthCodePkceSpotify,
) -> Result<Vec<TrackSummary>, LibraryError> {
    let tracks = client
        .current_user_saved_tracks_manual(None, Some(50), None)
        .await
        .map_err(|e| LibraryError::ApiError(e.to_string()))?;

    Ok(tracks
        .items
        .iter()
        .map(|saved| convert::track_to_summary(&saved.track))
        .collect())
}

/// Fetch user's followed artists (first 50)
pub async fn fetch_followed_artists(
    client: &AuthCodePkceSpotify,
) -> Result<Vec<ArtistSummary>, LibraryError> {
    let artists = client
        .current_user_followed_artists(None, Some(50))
        .await
        .map_err(|e| LibraryError::ApiError(e.to_string()))?;

    Ok(artists
        .items
        .iter()
        .map(convert::artist_to_summary)
        .collect())
}

/// Fetch all library content in parallel
pub async fn fetch_library(
    client: &AuthCodePkceSpotify,
) -> Result<LibraryContent, LibraryError> {
    let (playlists, saved_albums, saved_tracks, followed_artists) = tokio::try_join!(
        fetch_playlists(client),
        fetch_saved_albums(client),
        fetch_saved_tracks(client),
        fetch_followed_artists(client),
    )?;

    Ok(LibraryContent {
        playlists,
        saved_albums,
        saved_tracks,
        followed_artists,
    })
}
