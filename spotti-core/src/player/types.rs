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
    Toggle,
    Stop,
    Next,
    Previous,
    Seek(u32),
    LoadTrack { uri: String, start_playing: bool },
    LoadContext { uris: Vec<String>, index: usize },
    SetVolume(u16), // 0-65535 range, mapped from 0-100 at FFI layer
    SetShuffle(bool),
    SetRepeat(RepeatMode),
    /// Change audio bitrate: 0 = 96kbps, 1 = 160kbps, 2 = 320kbps.
    /// Takes effect on next track load.
    SetBitrate(u32),
    /// Gracefully stop playback and exit the run loop.
    Shutdown,
    /// Hot-swap the session on the existing player without destroying anything.
    Reconnect {
        session: librespot_core::Session,
        credentials: librespot_core::authentication::Credentials,
    },
}

/// Track metadata sent to the UI via events.
#[derive(Debug, Clone, Serialize)]
pub struct TrackInfo {
    pub id: String,
    pub uri: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u32,
    pub image_url: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub enum InitialStateSource {
    CurrentPlayback,
    RecentlyPlayed,
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
    CacheInfo { size_bytes: u64, item_count: u32 },
    CacheCleared,
    RadioTracksReady { name: String, uris: Vec<String>, tracks_json: String },
    TrackSavedStatus { is_saved: bool },
    TrackAddedToPlaylist,
    TrackTagsReady { tags: Vec<String> },
    SessionLost { message: String },
    PlaybackSynced {
        track: Option<TrackInfo>,   // None = nothing playing anywhere
        is_playing: bool,
        position_ms: u32,
        device_id: Option<String>,
        device_name: Option<String>,
        shuffle: bool,
        repeat: RepeatMode,
        is_our_device: bool,
    },
    InitialStateLoaded {
        track: Option<TrackInfo>,
        is_playing: bool,
        position_ms: u32,
        device_name: Option<String>,
        device_id: Option<String>,
        context_uri: Option<String>,
        source: InitialStateSource,
    },
}
