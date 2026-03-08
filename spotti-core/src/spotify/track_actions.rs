use rspotify::clients::{BaseClient, OAuthClient};
use rspotify::model::idtypes::{Id, PlayableId};
use rspotify::model::{ArtistId, PlaylistId, TrackId};
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

/// Get recommended track URIs seeded by up to 5 track IDs.
pub async fn get_recommendations(
    client: &AuthCodePkceSpotify,
    seed_track_ids: &[String],
) -> Result<Vec<String>, TrackActionError> {
    let seed_tracks: Vec<TrackId<'_>> = seed_track_ids
        .iter()
        .filter_map(|id| TrackId::from_id_or_uri(id).ok())
        .collect();

    if seed_tracks.is_empty() {
        return Err(TrackActionError::InvalidId("no valid seed track IDs".into()));
    }

    let recs = client
        .recommendations(
            std::iter::empty(),
            None::<std::iter::Empty<ArtistId>>,
            None::<std::iter::Empty<&str>>,
            Some(seed_tracks.into_iter()),
            None,
            Some(30),
        )
        .await
        .map_err(|e| TrackActionError::ApiError(e.to_string()))?;

    let uris: Vec<String> = recs
        .tracks
        .iter()
        .filter_map(|t| t.id.as_ref().map(|id| id.uri()))
        .collect();

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
