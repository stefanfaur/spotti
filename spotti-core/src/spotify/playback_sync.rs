use rspotify::clients::OAuthClient;
use rspotify::model::{PlayableItem, RepeatState};
use rspotify::AuthCodePkceSpotify;

use crate::player::types::{RepeatMode, TrackInfo};

pub struct PlaybackState {
    pub track: Option<TrackInfo>,
    pub is_playing: bool,
    pub position_ms: u32,
    pub device_id: Option<String>,
    pub device_name: Option<String>,
    pub shuffle: bool,
    pub repeat: RepeatMode,
}

pub async fn fetch_current_playback(
    client: &AuthCodePkceSpotify,
) -> Result<Option<PlaybackState>, rspotify::ClientError> {
    let ctx = client.current_playback(None, None::<&[_]>).await?;

    Ok(ctx.map(|c| {
        let track = match c.item {
            Some(PlayableItem::Track(t)) => Some(TrackInfo {
                id: t.id.as_ref().map(|id| id.to_string()).unwrap_or_default(),
                title: t.name,
                artist: t.artists.first().map(|a| a.name.clone()).unwrap_or_default(),
                album: t.album.name,
                duration_ms: t.duration.num_milliseconds() as u32,
                image_url: t.album.images.first().map(|img| img.url.clone()),
            }),
            _ => None,
        };

        let repeat = match c.repeat_state {
            RepeatState::Off => RepeatMode::Off,
            RepeatState::Track => RepeatMode::Track,
            RepeatState::Context => RepeatMode::Context,
        };

        PlaybackState {
            track,
            is_playing: c.is_playing,
            position_ms: c.progress
                .map(|d| d.num_milliseconds() as u32)
                .unwrap_or(0),
            device_id: c.device.id,
            device_name: Some(c.device.name),
            shuffle: c.shuffle_state,
            repeat,
        }
    }))
}
