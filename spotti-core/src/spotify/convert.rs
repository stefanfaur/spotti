use rspotify::model::{FullAlbum, FullArtist, FullTrack, SimplifiedAlbum, SimplifiedPlaylist, SimplifiedTrack};
use rspotify::prelude::Id;

use super::types::*;

pub fn track_to_summary(track: &FullTrack) -> TrackSummary {
    TrackSummary {
        id: track.id.as_ref().map(|id| id.to_string()).unwrap_or_default(),
        uri: track.id.as_ref().map(|id| id.uri()).unwrap_or_default(),
        name: track.name.clone(),
        artist: track
            .artists
            .first()
            .map(|a| a.name.clone())
            .unwrap_or_default(),
        album: track.album.name.clone(),
        duration_ms: track.duration.num_milliseconds() as u32,
        image_url: track.album.images.first().map(|img| img.url.clone()),
        track_number: Some(track.track_number),
        is_playable: track.is_playable.unwrap_or(true),
    }
}

pub fn simplified_track_to_summary(
    track: &SimplifiedTrack,
    album_name: &str,
    image_url: Option<&str>,
) -> TrackSummary {
    TrackSummary {
        id: track.id.as_ref().map(|id| id.to_string()).unwrap_or_default(),
        uri: track.id.as_ref().map(|id| id.uri()).unwrap_or_default(),
        name: track.name.clone(),
        artist: track
            .artists
            .first()
            .map(|a| a.name.clone())
            .unwrap_or_default(),
        album: album_name.to_string(),
        duration_ms: track.duration.num_milliseconds() as u32,
        image_url: image_url.map(|s| s.to_string()),
        track_number: Some(track.track_number),
        is_playable: track.is_playable.unwrap_or(true),
    }
}

pub fn artist_to_summary(artist: &FullArtist) -> ArtistSummary {
    ArtistSummary {
        id: artist.id.to_string(),
        name: artist.name.clone(),
        image_url: artist.images.first().map(|img| img.url.clone()),
    }
}

pub fn full_album_to_summary(album: &FullAlbum) -> AlbumSummary {
    AlbumSummary {
        id: album.id.to_string(),
        name: album.name.clone(),
        artist: album
            .artists
            .first()
            .map(|a| a.name.clone())
            .unwrap_or_default(),
        image_url: album.images.first().map(|img| img.url.clone()),
        release_year: Some(album.release_date.chars().take(4).collect()),
        track_count: album.tracks.total,
    }
}

pub fn simplified_album_to_summary(album: &SimplifiedAlbum) -> AlbumSummary {
    AlbumSummary {
        id: album
            .id
            .as_ref()
            .map(|id| id.to_string())
            .unwrap_or_default(),
        name: album.name.clone(),
        artist: album
            .artists
            .first()
            .map(|a| a.name.clone())
            .unwrap_or_default(),
        image_url: album.images.first().map(|img| img.url.clone()),
        release_year: album
            .release_date
            .as_ref()
            .map(|d| d.chars().take(4).collect()),
        track_count: 0, // SimplifiedAlbum doesn't have track count
    }
}

pub fn playlist_to_summary(playlist: &SimplifiedPlaylist) -> PlaylistSummary {
    PlaylistSummary {
        id: playlist.id.to_string(),
        name: playlist.name.clone(),
        owner: playlist
            .owner
            .display_name
            .clone()
            .unwrap_or_default(),
        track_count: playlist.tracks.total,
        image_url: playlist.images.first().map(|img| img.url.clone()),
    }
}
