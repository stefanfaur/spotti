use rspotify::clients::BaseClient;
use rspotify::model::SearchType;
use rspotify::AuthCodePkceSpotify;

use super::convert;
use super::types::*;

/// Search Spotify across all types. Limit is 10 per type (Feb 2026 cap).
pub async fn search(
    client: &AuthCodePkceSpotify,
    query: &str,
    offset: u32,
) -> Result<SearchResults, SearchError> {
    let limit = 10u32;
    let types = [
        SearchType::Track,
        SearchType::Artist,
        SearchType::Album,
        SearchType::Playlist,
    ];

    let result = client
        .search_multiple(query, types, None, None, Some(limit), Some(offset))
        .await
        .map_err(|e| SearchError::ApiError(e.to_string()))?;

    let tracks = result
        .tracks
        .map(|page| page.items.iter().map(convert::track_to_summary).collect())
        .unwrap_or_default();

    let artists = result
        .artists
        .map(|page| page.items.iter().map(convert::artist_to_summary).collect())
        .unwrap_or_default();

    let albums = result
        .albums
        .map(|page| {
            page.items
                .iter()
                .map(convert::simplified_album_to_summary)
                .collect()
        })
        .unwrap_or_default();

    let playlists = result
        .playlists
        .map(|page| {
            page.items
                .iter()
                .map(convert::playlist_to_summary)
                .collect()
        })
        .unwrap_or_default();

    Ok(SearchResults {
        query: query.to_string(),
        tracks,
        artists,
        albums,
        playlists,
    })
}

#[derive(Debug, thiserror::Error)]
pub enum SearchError {
    #[error("Spotify API error: {0}")]
    ApiError(String),
}
