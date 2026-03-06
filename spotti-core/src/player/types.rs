use serde::Serialize;

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
}

/// Track metadata sent to the UI via events.
#[derive(Debug, Clone, Serialize)]
pub struct TrackInfo {
    pub id: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u32,
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
}
