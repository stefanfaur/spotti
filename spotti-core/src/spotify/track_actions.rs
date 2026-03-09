use rspotify::clients::{BaseClient, OAuthClient};
use rspotify::model::idtypes::{Id, PlayableId};
use rspotify::model::{FullTrack, Market, PlaylistId, SearchResult, SearchType, TrackId};
use rspotify::AuthCodePkceSpotify;

use crate::player::types::TrackInfo;

#[derive(Debug, thiserror::Error)]
pub enum TrackActionError {
    #[error("Spotify API error: {0}")]
    ApiError(String),
    #[error("invalid ID: {0}")]
    InvalidId(String),
    #[error("no recommendations returned")]
    Empty,
}

pub struct RadioResult {
    pub name: String,
    pub tracks: Vec<TrackInfo>,
}

/// Build a radio playlist seeded by up to 5 track IDs.
///
/// For single-seed (song radio), uses Last.fm `track.getSimilar` for more targeted results.
/// Falls back to `artist.getSimilar` if not enough tracks, or for multi-seed (playlist radio).
pub async fn get_recommendations(
    client: &AuthCodePkceSpotify,
    seed_track_ids: &[String],
    lastfm_api_key: &str,
    radio_name: Option<String>,
) -> Result<RadioResult, TrackActionError> {
    log::info!("[radio] get_recommendations called with seeds: {:?}", seed_track_ids);

    // Resolve artist name and track name from first seed track
    let mut artist_name: Option<String> = None;
    let mut seed_track_name: Option<String> = None;
    for id_str in seed_track_ids.iter().take(3) {
        match TrackId::from_id_or_uri(id_str) {
            Ok(tid) => {
                log::info!("[radio] fetching track info for id={}", id_str);
                match client.track(tid, None).await {
                    Ok(full_track) => {
                        if let Some(a) = full_track.artists.first() {
                            artist_name = Some(a.name.clone());
                            seed_track_name = Some(full_track.name.clone());
                            log::info!("[radio] resolved artist '{}'", a.name);
                            break;
                        }
                    }
                    Err(e) => log::warn!("[radio] client.track() failed for {}: {}", id_str, e),
                }
            }
            Err(e) => log::warn!("[radio] invalid track id '{}': {}", id_str, e),
        }
    }

    let artist_name = artist_name.ok_or_else(|| {
        TrackActionError::ApiError("could not resolve artist name from seed track".to_string())
    })?;

    let name = radio_name.unwrap_or_else(|| {
        format!("{} Radio", seed_track_name.as_deref().unwrap_or(&artist_name))
    });

    let mut tracks: Vec<TrackInfo> = Vec::new();

    // Song radio (single seed): use track.getSimilar for more targeted results
    if seed_track_ids.len() == 1 {
        if let Some(ref track_name) = seed_track_name {
            let similar = lastfm_similar_tracks(track_name, &artist_name, lastfm_api_key).await
                .unwrap_or_default();
            log::info!("[radio] track.getSimilar returned {} results", similar.len());

            for (t_name, t_artist) in similar.iter().take(30) {
                if let Some(info) = search_track_on_spotify(client, t_name, t_artist).await {
                    tracks.push(info);
                }
            }
            log::info!("[radio] after track.getSimilar search: {} tracks", tracks.len());
        }
    }

    // Fall back to artist.getSimilar if we don't have enough tracks
    // (also the primary path for playlist radio with multiple seeds)
    if tracks.len() < 10 {
        log::info!("[radio] topping up with artist.getSimilar (have {} tracks)", tracks.len());
        let similar_names = lastfm_similar_artists(&artist_name, lastfm_api_key).await?;
        log::info!("[radio] Last.fm returned {} similar artists", similar_names.len());

        for similar_name in similar_names.iter().take(8) {
            let query = format!("artist:{}", similar_name);
            match client
                .search(&query, SearchType::Artist, None, None, Some(1), None)
                .await
            {
                Ok(SearchResult::Artists(page)) => {
                    if let Some(spotify_artist) = page.items.into_iter().next() {
                        match client.artist_top_tracks(spotify_artist.id, Some(Market::FromToken)).await {
                            Ok(top_tracks) => {
                                for track in top_tracks.iter().take(5) {
                                    tracks.push(full_track_to_info(track));
                                }
                            }
                            Err(e) => log::warn!("[radio] artist_top_tracks failed: {}", e),
                        }
                    }
                }
                Ok(_) => {}
                Err(e) => log::warn!("[radio] search failed for '{}': {}", similar_name, e),
            }
        }
    }

    log::info!("[radio] total radio tracks collected: {}", tracks.len());

    if tracks.is_empty() {
        return Err(TrackActionError::Empty);
    }
    Ok(RadioResult { name, tracks })
}

fn full_track_to_info(track: &FullTrack) -> TrackInfo {
    TrackInfo {
        id: track.id.as_ref().map(|id| id.to_string()).unwrap_or_default(),
        uri: track.id.as_ref().map(|id| id.uri()).unwrap_or_default(),
        title: track.name.clone(),
        artist: track.artists.first().map(|a| a.name.clone()).unwrap_or_default(),
        album: track.album.name.clone(),
        duration_ms: track.duration.num_milliseconds() as u32,
        image_url: track.album.images.first().map(|img| img.url.clone()),
    }
}

async fn lastfm_similar_artists(
    artist: &str,
    api_key: &str,
) -> Result<Vec<String>, TrackActionError> {
    let url = format!(
        "https://ws.audioscrobbler.com/2.0/?method=artist.getSimilar&artist={}&api_key={}&limit=10&format=json",
        urlencoding::encode(artist),
        api_key,
    );
    log::info!("[lastfm] artist.getSimilar request for '{}'", artist);

    let response = reqwest::get(&url)
        .await
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm request failed: {}", e)))?
        .text()
        .await
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm response read failed: {}", e)))?;

    let json: serde_json::Value = serde_json::from_str(&response)
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm JSON parse failed: {}", e)))?;

    if let Some(err) = json.get("error") {
        let msg = json.get("message").and_then(|m| m.as_str()).unwrap_or("unknown");
        log::error!("[lastfm] artist.getSimilar API error {}: {}", err, msg);
        return Err(TrackActionError::ApiError(format!("Last.fm error {}: {}", err, msg)));
    }

    let names = json["similarartists"]["artist"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|a| a["name"].as_str().map(String::from))
        .collect();

    Ok(names)
}

/// Returns similar tracks as (track_name, artist_name) pairs via Last.fm track.getSimilar.
async fn lastfm_similar_tracks(
    track: &str,
    artist: &str,
    api_key: &str,
) -> Result<Vec<(String, String)>, TrackActionError> {
    let url = format!(
        "https://ws.audioscrobbler.com/2.0/?method=track.getSimilar&track={}&artist={}&api_key={}&limit=30&autocorrect=1&format=json",
        urlencoding::encode(track),
        urlencoding::encode(artist),
        api_key,
    );
    log::info!("[lastfm] track.getSimilar request for '{}' by '{}'", track, artist);

    let response = reqwest::get(&url)
        .await
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm request failed: {}", e)))?
        .text()
        .await
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm response read failed: {}", e)))?;

    let json: serde_json::Value = serde_json::from_str(&response)
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm JSON parse failed: {}", e)))?;

    if let Some(err) = json.get("error") {
        let msg = json.get("message").and_then(|m| m.as_str()).unwrap_or("unknown");
        log::error!("[lastfm] track.getSimilar API error {}: {}", err, msg);
        return Err(TrackActionError::ApiError(format!("Last.fm error {}: {}", err, msg)));
    }

    let pairs = json["similartracks"]["track"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|t| {
            let name = t["name"].as_str()?.to_string();
            let artist = t["artist"]["name"].as_str()?.to_string();
            Some((name, artist))
        })
        .collect();

    Ok(pairs)
}

/// Search Spotify for a specific track by name+artist, return the first match as TrackInfo.
async fn search_track_on_spotify(
    client: &AuthCodePkceSpotify,
    track_name: &str,
    artist_name: &str,
) -> Option<TrackInfo> {
    let query = format!("track:{} artist:{}", track_name, artist_name);
    match client
        .search(&query, SearchType::Track, None, None, Some(1), None)
        .await
    {
        Ok(SearchResult::Tracks(page)) => {
            page.items.into_iter().next().map(|t| full_track_to_info(&t))
        }
        _ => None,
    }
}

/// Returns (bio_summary, tags) from Last.fm artist.getInfo.
/// Bio has the trailing "Read more on Last.fm" link stripped.
pub async fn lastfm_artist_info(
    artist: &str,
    api_key: &str,
) -> Option<(String, Vec<String>)> {
    log::info!("[lastfm] artist.getInfo request for '{}'", artist);
    let url = format!(
        "https://ws.audioscrobbler.com/2.0/?method=artist.getInfo&artist={}&api_key={}&autocorrect=1&format=json",
        urlencoding::encode(artist),
        api_key,
    );
    let response = match reqwest::get(&url).await {
        Ok(r) => r,
        Err(e) => {
            log::warn!("[lastfm] artist.getInfo HTTP request failed: {}", e);
            return None;
        }
    };
    let text = match response.text().await {
        Ok(t) => t,
        Err(e) => {
            log::warn!("[lastfm] artist.getInfo failed to read response body: {}", e);
            return None;
        }
    };
    let json: serde_json::Value = match serde_json::from_str(&text) {
        Ok(j) => j,
        Err(e) => {
            log::warn!("[lastfm] artist.getInfo JSON parse failed: {}", e);
            return None;
        }
    };

    if let Some(err) = json.get("error") {
        let msg = json.get("message").and_then(|m| m.as_str()).unwrap_or("unknown");
        log::warn!("[lastfm] artist.getInfo API error {}: {}", err, msg);
        return None;
    }

    let bio_raw = json["artist"]["bio"]["summary"].as_str().unwrap_or("").to_string();
    let bio = bio_raw
        .split("<a href=")
        .next()
        .unwrap_or(&bio_raw)
        .trim()
        .to_string();
    let bio = if bio.is_empty() {
        log::info!("[lastfm] artist.getInfo: no bio found for '{}'", artist);
        return None;
    } else { bio };

    let tags: Vec<String> = json["artist"]["tags"]["tag"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|t| t["name"].as_str().map(String::from))
        .take(5)
        .collect();

    log::info!("[lastfm] artist.getInfo for '{}': bio_len={}, tags={:?}", artist, bio.len(), tags);
    Some((bio, tags))
}

/// Returns (wiki_summary, tags) from Last.fm album.getInfo.
pub async fn lastfm_album_info(
    album: &str,
    artist: &str,
    api_key: &str,
) -> Option<(String, Vec<String>)> {
    log::info!("[lastfm] album.getInfo request for '{}' by '{}'", album, artist);
    let url = format!(
        "https://ws.audioscrobbler.com/2.0/?method=album.getInfo&album={}&artist={}&api_key={}&autocorrect=1&format=json",
        urlencoding::encode(album),
        urlencoding::encode(artist),
        api_key,
    );
    let response = match reqwest::get(&url).await {
        Ok(r) => r,
        Err(e) => {
            log::warn!("[lastfm] album.getInfo HTTP request failed: {}", e);
            return None;
        }
    };
    let text = match response.text().await {
        Ok(t) => t,
        Err(e) => {
            log::warn!("[lastfm] album.getInfo failed to read response body: {}", e);
            return None;
        }
    };
    let json: serde_json::Value = match serde_json::from_str(&text) {
        Ok(j) => j,
        Err(e) => {
            log::warn!("[lastfm] album.getInfo JSON parse failed: {}", e);
            return None;
        }
    };

    if let Some(err) = json.get("error") {
        let msg = json.get("message").and_then(|m| m.as_str()).unwrap_or("unknown");
        log::warn!("[lastfm] album.getInfo API error {}: {}", err, msg);
        return None;
    }

    let wiki_raw = json["album"]["wiki"]["summary"].as_str().unwrap_or("").to_string();
    let wiki = wiki_raw
        .split("<a href=")
        .next()
        .unwrap_or(&wiki_raw)
        .trim()
        .to_string();
    let wiki = if wiki.is_empty() {
        log::info!("[lastfm] album.getInfo: no wiki found for '{}' by '{}'", album, artist);
        return None;
    } else { wiki };

    let tags: Vec<String> = json["album"]["tags"]["tag"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|t| t["name"].as_str().map(String::from))
        .take(5)
        .collect();

    log::info!("[lastfm] album.getInfo for '{}' by '{}': wiki_len={}, tags={:?}", album, artist, wiki.len(), tags);
    Some((wiki, tags))
}

/// Returns top crowd-sourced tags for a track via Last.fm track.getTopTags.
pub async fn lastfm_track_top_tags(
    track: &str,
    artist: &str,
    api_key: &str,
) -> Vec<String> {
    log::info!("[lastfm] track.getTopTags request for track='{}' artist='{}'", track, artist);
    if api_key.is_empty() {
        log::warn!("[lastfm] API key is empty, skipping track.getTopTags");
        return vec![];
    }
    let url = format!(
        "https://ws.audioscrobbler.com/2.0/?method=track.getTopTags&track={}&artist={}&api_key={}&autocorrect=1&format=json",
        urlencoding::encode(track),
        urlencoding::encode(artist),
        api_key,
    );
    let response = match reqwest::get(&url).await {
        Ok(r) => r,
        Err(e) => {
            log::warn!("[lastfm] track.getTopTags HTTP request failed: {}", e);
            return vec![];
        }
    };
    let text = match response.text().await {
        Ok(t) => t,
        Err(e) => {
            log::warn!("[lastfm] track.getTopTags failed to read response body: {}", e);
            return vec![];
        }
    };
    let json: serde_json::Value = match serde_json::from_str(&text) {
        Ok(j) => j,
        Err(e) => {
            log::warn!("[lastfm] track.getTopTags JSON parse failed: {}", e);
            return vec![];
        }
    };

    if json.get("error").is_some() {
        log::warn!("[lastfm] track.getTopTags API error: {}", json);
        return vec![];
    }

    let tags: Vec<String> = json["toptags"]["tag"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|t| t["name"].as_str().map(String::from))
        .take(5)
        .collect();
    log::info!("[lastfm] track.getTopTags result: {} tags: {:?}", tags.len(), tags);
    tags
}

/// Build a radio playlist from a Last.fm tag/genre (e.g. "indie rock").
/// Calls tag.getTopTracks, then searches Spotify for each track.
pub async fn get_tag_recommendations(
    client: &AuthCodePkceSpotify,
    tag: &str,
    lastfm_api_key: &str,
) -> Result<RadioResult, TrackActionError> {
    log::info!("[lastfm] tag.getTopTracks request for tag='{}'", tag);

    let url = format!(
        "https://ws.audioscrobbler.com/2.0/?method=tag.getTopTracks&tag={}&api_key={}&limit=50&format=json",
        urlencoding::encode(tag),
        lastfm_api_key,
    );

    let response = reqwest::get(&url)
        .await
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm request failed: {}", e)))?
        .text()
        .await
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm response read failed: {}", e)))?;

    let json: serde_json::Value = serde_json::from_str(&response)
        .map_err(|e| TrackActionError::ApiError(format!("Last.fm JSON parse failed: {}", e)))?;

    if let Some(err) = json.get("error") {
        let msg = json.get("message").and_then(|m| m.as_str()).unwrap_or("unknown");
        return Err(TrackActionError::ApiError(format!("Last.fm error {}: {}", err, msg)));
    }

    let pairs: Vec<(String, String)> = json["tracks"]["track"]
        .as_array()
        .unwrap_or(&vec![])
        .iter()
        .filter_map(|t| {
            let name = t["name"].as_str()?.to_string();
            let artist = t["artist"]["name"].as_str()?.to_string();
            Some((name, artist))
        })
        .collect();

    log::info!("[lastfm] tag.getTopTracks returned {} results", pairs.len());

    let mut tracks: Vec<TrackInfo> = Vec::new();
    for (t_name, t_artist) in pairs.iter().take(40) {
        if let Some(info) = search_track_on_spotify(client, t_name, t_artist).await {
            tracks.push(info);
        }
        if tracks.len() >= 30 {
            break;
        }
    }

    log::info!("[lastfm] tag.getTopTracks resolved {} Spotify tracks for tag='{}'", tracks.len(), tag);

    if tracks.is_empty() {
        return Err(TrackActionError::Empty);
    }

    Ok(RadioResult {
        name: format!("{} Radio", capitalize_first(tag)),
        tracks,
    })
}

fn capitalize_first(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(c) => c.to_uppercase().collect::<String>() + chars.as_str(),
    }
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
