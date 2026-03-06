use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub enum RepeatMode {
    Off,
    Context,
    Track,
}

/// Commands sent from FFI/UI to the player engine.
pub enum PlayerCommand {
    Play,
    Pause,
    Stop,
    Next,
    Previous,
    Seek(u32),
    LoadTrack { uri: String, start_playing: bool },
    LoadContext { uris: Vec<String>, index: usize },
    SetVolume(u16), // 0-65535 range, mapped from 0-100 at FFI layer
    SetShuffle(bool),
    SetRepeat(RepeatMode),
}

/// Track metadata sent to the UI via events.
#[derive(Debug, Clone, Serialize)]
pub struct TrackInfo {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u32,
    pub image_url: Option<String>,
}

/// Events emitted by the player engine to the UI.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type")]
pub enum PlayerEvent {
    Playing { track: TrackInfo, position_ms: u32 },
    Paused { track: TrackInfo, position_ms: u32 },
    Stopped,
    TrackChanged { track: TrackInfo },
    Loading { uri: String },
    EndOfTrack,
    Error { message: String },
    PositionChanged { position_ms: u32 },
    VolumeChanged { volume: u16 },
    ShuffleChanged { enabled: bool },
    RepeatChanged { mode: RepeatMode },
    SearchResults { results_json: String },
    LibraryContent { content_json: String },
    PlaylistDetail { detail_json: String },
    AlbumDetail { detail_json: String },
    ArtistDetail { detail_json: String },
    ArtCached { id: String, path: String },
    DeviceList { devices_json: String },
    DeviceTransferred { device_id: String },
}
