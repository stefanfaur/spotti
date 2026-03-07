use std::sync::mpsc as std_mpsc;
use std::time::Duration;

use souvlaki::{
    MediaControlEvent, MediaControls, MediaMetadata, MediaPlayback, MediaPosition,
    PlatformConfig,
};

/// Commands sent to the NowPlaying thread.
pub enum NowPlayingCommand {
    SetMetadata {
        title: String,
        artist: String,
        album: String,
        cover_url: Option<String>,
        duration_ms: u32,
    },
    SetPlaying {
        position_ms: u32,
    },
    SetPaused {
        position_ms: u32,
    },
    SetStopped,
    UpdatePosition {
        position_ms: u32,
        is_playing: bool,
    },
}

/// Simplified actions from system media controls back to the player.
#[derive(Debug, Clone)]
pub enum MediaControlAction {
    Play,
    Pause,
    Toggle,
    Next,
    Previous,
    Stop,
    SeekTo(u32),
}

/// Spawns the Now Playing service on a dedicated thread.
/// Returns a sender for sending commands to the service.
pub fn spawn_now_playing_service(
    on_media_event: impl Fn(MediaControlAction) + Send + 'static,
) -> Result<std_mpsc::Sender<NowPlayingCommand>, String> {
    let (tx, rx) = std_mpsc::channel::<NowPlayingCommand>();

    std::thread::Builder::new()
        .name("spotti-now-playing".to_string())
        .spawn(move || {
            let config = PlatformConfig {
                dbus_name: "com.spotti.player",
                display_name: "Spotti",
                hwnd: None,
            };

            let mut controls = match MediaControls::new(config) {
                Ok(c) => c,
                Err(e) => {
                    log::error!("Failed to create MediaControls: {e}");
                    return;
                }
            };

            if let Err(e) = controls.attach(move |event: MediaControlEvent| {
                let action = match event {
                    MediaControlEvent::Play => Some(MediaControlAction::Play),
                    MediaControlEvent::Pause => Some(MediaControlAction::Pause),
                    MediaControlEvent::Toggle => Some(MediaControlAction::Toggle),
                    MediaControlEvent::Next => Some(MediaControlAction::Next),
                    MediaControlEvent::Previous => Some(MediaControlAction::Previous),
                    MediaControlEvent::Stop => Some(MediaControlAction::Stop),
                    MediaControlEvent::SetPosition(pos) => {
                        Some(MediaControlAction::SeekTo(pos.0.as_millis() as u32))
                    }
                    _ => None,
                };
                if let Some(action) = action {
                    on_media_event(action);
                }
            }) {
                log::error!("Failed to attach media controls: {e}");
                return;
            }

            while let Ok(cmd) = rx.recv() {
                let result = match cmd {
                    NowPlayingCommand::SetMetadata {
                        title,
                        artist,
                        album,
                        cover_url,
                        duration_ms,
                    } => controls.set_metadata(MediaMetadata {
                        title: Some(&title),
                        artist: Some(&artist),
                        album: Some(&album),
                        cover_url: cover_url.as_deref(),
                        duration: Some(Duration::from_millis(duration_ms as u64)),
                    }),
                    NowPlayingCommand::SetPlaying { position_ms } => {
                        controls.set_playback(MediaPlayback::Playing {
                            progress: Some(MediaPosition(Duration::from_millis(
                                position_ms as u64,
                            ))),
                        })
                    }
                    NowPlayingCommand::SetPaused { position_ms } => {
                        controls.set_playback(MediaPlayback::Paused {
                            progress: Some(MediaPosition(Duration::from_millis(
                                position_ms as u64,
                            ))),
                        })
                    }
                    NowPlayingCommand::SetStopped => {
                        controls.set_playback(MediaPlayback::Stopped)
                    }
                    NowPlayingCommand::UpdatePosition { position_ms, is_playing } => {
                        let progress = Some(MediaPosition(Duration::from_millis(
                            position_ms as u64,
                        )));
                        if is_playing {
                            controls.set_playback(MediaPlayback::Playing { progress })
                        } else {
                            controls.set_playback(MediaPlayback::Paused { progress })
                        }
                    }
                };

                if let Err(e) = result {
                    log::warn!("Now Playing update failed: {e}");
                }
            }

            log::info!("Now Playing service shutting down");
        })
        .map_err(|e| format!("Failed to spawn now-playing thread: {e}"))?;

    Ok(tx)
}
