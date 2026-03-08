use rspotify::clients::{BaseClient, OAuthClient};
use rspotify::model::idtypes::{Id, PlayableId};
use rspotify::model::{Market, PlaylistId, TrackId};
use rspotify::AuthCodePkceSpotify;

#[derive(Debug, thiserror::Error)]
pub enum TrackActionError {
    #[error("Spotify API error: {0}")]
    ApiError(String),
    #[error("invalid ID: {0}")]
    InvalidId(String),
    #[error("no recommendations returned")]
    Empty,
}

/// Build a radio playlist seeded by up to 5 track IDs.
#[allow(deprecated)]
/// Resolves the first seed track's artist, fetches related artists, and
/// returns their top tracks (up to ~30 URIs). Uses only endpoints that are
/// available to all app tiers (the recommendations endpoint was deprecated
/// for apps created after Nov 2024).
pub async fn get_recommendations(
    client: &AuthCodePkceSpotify,
    seed_track_ids: &[String],
) -> Result<Vec<String>, TrackActionError> {
    // Step 1: resolve artist ID from the first valid seed track
    let mut artist_id = None;
    for id_str in seed_track_ids.iter().take(3) {
        if let Ok(tid) = TrackId::from_id_or_uri(id_str) {
            if let Ok(full_track) = client.track(tid, None).await {
                if let Some(a) = full_track.artists.first() {
                    artist_id = a.id.clone();
                    if artist_id.is_some() {
                        break;
                    }
                }
            }
        }
    }

    let artist_id = artist_id.ok_or_else(|| {
        TrackActionError::ApiError("could not resolve artist ID from seed track".into())
    })?;

    // Step 2: fetch related artists
    let related = client
        .artist_related_artists(artist_id)
        .await
        .map_err(|e| TrackActionError::ApiError(e.to_string()))?;

    // Step 3: collect top tracks from up to 6 related artists (~5 tracks each)
    let mut uris = Vec::new();
    for artist in related.iter().take(6) {
        if let Ok(tracks) = client
            .artist_top_tracks(artist.id.clone(), Some(Market::FromToken))
            .await
        {
            for track in tracks.iter().take(5) {
                if let Some(id) = &track.id {
                    uris.push(id.uri());
                }
            }
        }
    }

    if uris.is_empty() {
        return Err(TrackActionError::Empty);
    }
    Ok(uris)
}

/// Save a track to the user's liked songs.
pub async fn save_track(
    client: &AuthCodePkceSpotify,
    track_id: &str,
) -> Result<(), TrackActionError> {
    let id = TrackId::from_id_or_uri(track_id)
        .map_err(|e| TrackActionError::InvalidId(e.to_string()))?;
    client
        .current_user_saved_tracks_add([id])
        .await
        .map_err(|e| TrackActionError::ApiError(e.to_string()))
}

/// Remove a track from the user's liked songs.
pub async fn unsave_track(
    client: &AuthCodePkceSpotify,
    track_id: &str,
) -> Result<(), TrackActionError> {
    let id = TrackId::from_id_or_uri(track_id)
        .map_err(|e| TrackActionError::InvalidId(e.to_string()))?;
    client
        .current_user_saved_tracks_delete([id])
        .await
        .map_err(|e| TrackActionError::ApiError(e.to_string()))
}

/// Check if a track is saved in the user's liked songs.
pub async fn check_saved(
    client: &AuthCodePkceSpotify,
    track_id: &str,
) -> Result<bool, TrackActionError> {
    let id = TrackId::from_id_or_uri(track_id)
        .map_err(|e| TrackActionError::InvalidId(e.to_string()))?;
    let result = client
        .current_user_saved_tracks_contains([id])
        .await
        .map_err(|e| TrackActionError::ApiError(e.to_string()))?;
    Ok(result.first().copied().unwrap_or(false))
}

/// Add a track to a playlist.
pub async fn add_to_playlist(
    client: &AuthCodePkceSpotify,
    playlist_id: &str,
    track_uri: &str,
) -> Result<(), TrackActionError> {
    let pid = PlaylistId::from_id_or_uri(playlist_id)
        .map_err(|e| TrackActionError::InvalidId(e.to_string()))?;
    let tid = TrackId::from_id_or_uri(track_uri)
        .map_err(|e| TrackActionError::InvalidId(e.to_string()))?;
    client
        .playlist_add_items(pid, [PlayableId::Track(tid)], None)
        .await
        .map_err(|e| TrackActionError::ApiError(e.to_string()))?;
    Ok(())
}
