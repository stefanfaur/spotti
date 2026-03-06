use rspotify::clients::BaseClient;
use rspotify::model::{AlbumId, ArtistId, PlayableItem, PlaylistId};
use rspotify::AuthCodePkceSpotify;

use super::convert;
use super::types::*;

#[derive(Debug, thiserror::Error)]
pub enum DetailError {
    #[error("Spotify API error: {0}")]
    ApiError(String),
    #[error("invalid ID: {0}")]
    InvalidId(String),
}

pub async fn fetch_playlist(
    client: &AuthCodePkceSpotify,
    playlist_id: &str,
) -> Result<PlaylistDetail, DetailError> {
    let id = PlaylistId::from_id_or_uri(playlist_id)
        .map_err(|e| DetailError::InvalidId(e.to_string()))?;

    let playlist = client
        .playlist(id, None, None)
        .await
        .map_err(|e| DetailError::ApiError(e.to_string()))?;

    let tracks: Vec<TrackSummary> = playlist
        .tracks
        .items
        .iter()
        .filter_map(|item| {
            if let Some(PlayableItem::Track(track)) = &item.track {
                Some(convert::track_to_summary(track))
            } else {
                None
            }
        })
        .collect();

    Ok(PlaylistDetail {
        id: playlist.id.to_string(),
        name: playlist.name,
        owner: playlist.owner.display_name.unwrap_or_default(),
        description: playlist.description,
        image_url: playlist.images.first().map(|img| img.url.clone()),
        total_tracks: playlist.tracks.total,
        tracks,
    })
}

pub async fn fetch_album(
    client: &AuthCodePkceSpotify,
    album_id: &str,
) -> Result<AlbumDetail, DetailError> {
    let id =
        AlbumId::from_id_or_uri(album_id).map_err(|e| DetailError::InvalidId(e.to_string()))?;

    let album = client
        .album(id, None)
        .await
        .map_err(|e| DetailError::ApiError(e.to_string()))?;

    let image_url = album.images.first().map(|img| img.url.as_str());
    let tracks: Vec<TrackSummary> = album
        .tracks
        .items
        .iter()
        .map(|t| convert::simplified_track_to_summary(t, &album.name, image_url))
        .collect();

    Ok(AlbumDetail {
        id: album.id.to_string(),
        name: album.name.clone(),
        artist: album
            .artists
            .first()
            .map(|a| a.name.clone())
            .unwrap_or_default(),
        image_url: image_url.map(|s| s.to_string()),
        release_date: Some(album.release_date.clone()),
        total_tracks: album.tracks.total,
        tracks,
    })
}

pub async fn fetch_artist(
    client: &AuthCodePkceSpotify,
    artist_id: &str,
) -> Result<ArtistDetail, DetailError> {
    let id = ArtistId::from_id_or_uri(artist_id)
        .map_err(|e| DetailError::InvalidId(e.to_string()))?;

    let artist = client
        .artist(id.clone())
        .await
        .map_err(|e| DetailError::ApiError(e.to_string()))?;

    // Fetch artist's albums (no top tracks -- endpoint removed Feb 2026)
    let albums_page = client
        .artist_albums_manual(id, [], None, Some(50), None)
        .await
        .map_err(|e| DetailError::ApiError(e.to_string()))?;

    let albums: Vec<AlbumSummary> = albums_page
        .items
        .iter()
        .map(convert::simplified_album_to_summary)
        .collect();

    Ok(ArtistDetail {
        id: artist.id.to_string(),
        name: artist.name,
        image_url: artist.images.first().map(|img| img.url.clone()),
        follower_count: artist.followers.total,
        albums,
    })
}
