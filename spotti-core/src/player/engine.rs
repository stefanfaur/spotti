use std::sync::Arc;
use std::time::Duration;

use crossbeam_channel::Sender;
use librespot_core::Session;
use librespot_core::SpotifyUri;
use librespot_metadata::audio::AudioItem;
use librespot_playback::audio_backend;
use librespot_playback::config::{AudioFormat, Bitrate, PlayerConfig};
use librespot_playback::mixer::NoOpVolume;
use librespot_playback::player::{Player, PlayerEvent as LibrespotEvent};
use tokio::sync::mpsc;

use super::types::{PlayerCommand, PlayerEvent, TrackInfo};

pub struct PlayerEngine {
    player: Arc<Player>,
    cmd_rx: mpsc::Receiver<PlayerCommand>,
    event_tx: Sender<PlayerEvent>,
    queue: Vec<String>,
    queue_index: usize,
    current_track: Option<TrackInfo>,
}

impl PlayerEngine {
    pub fn new(
        session: Session,
        cmd_rx: mpsc::Receiver<PlayerCommand>,
        event_tx: Sender<PlayerEvent>,
    ) -> Result<Self, String> {
        let player_config = PlayerConfig {
            bitrate: Bitrate::Bitrate320,
            gapless: true,
            position_update_interval: Some(Duration::from_secs(1)),
            ..PlayerConfig::default()
        };

        let backend = audio_backend::find(None)
            .ok_or("No audio backend found (rodio expected)")?;
        let audio_format = AudioFormat::default();

        let player = Player::new(
            player_config,
            session,
            Box::new(NoOpVolume),
            move || backend(None, audio_format),
        );

        Ok(Self {
            player,
            cmd_rx,
            event_tx,
            queue: Vec::new(),
            queue_index: 0,
            current_track: None,
        })
    }

    /// Main run loop. Call this from a spawned tokio task.
    pub async fn run(mut self) {
        let mut event_channel = self.player.get_player_event_channel();

        loop {
            tokio::select! {
                event = event_channel.recv() => {
                    match event {
                        Some(event) => self.handle_librespot_event(event),
                        None => break,
                    }
                }
                cmd = self.cmd_rx.recv() => {
                    match cmd {
                        Some(cmd) => self.handle_command(cmd),
                        None => break,
                    }
                }
            }
        }
    }

    fn handle_command(&mut self, cmd: PlayerCommand) {
        match cmd {
            PlayerCommand::Play => self.player.play(),
            PlayerCommand::Pause => self.player.pause(),
            PlayerCommand::Stop => self.player.stop(),
            PlayerCommand::Seek(pos_ms) => self.player.seek(pos_ms),
            PlayerCommand::Next => {
                if self.queue_index + 1 < self.queue.len() {
                    self.queue_index += 1;
                    self.load_current_track(true);
                }
            }
            PlayerCommand::Previous => {
                if self.queue_index > 0 {
                    self.queue_index -= 1;
                    self.load_current_track(true);
                }
            }
            PlayerCommand::LoadTrack { uri, start_playing } => {
                self.queue = vec![uri];
                self.queue_index = 0;
                self.load_current_track(start_playing);
            }
            PlayerCommand::LoadContext { uris, index } => {
                self.queue = uris;
                self.queue_index = index;
                self.load_current_track(true);
            }
        }
    }

    fn load_current_track(&mut self, start_playing: bool) {
        let Some(uri_str) = self.queue.get(self.queue_index) else {
            return;
        };

        let _ = self.event_tx.send(PlayerEvent::Loading {
            uri: uri_str.clone(),
        });

        match SpotifyUri::from_uri(uri_str) {
            Ok(spotify_uri) => {
                self.player.load(spotify_uri, start_playing, 0);
            }
            Err(e) => {
                let _ = self.event_tx.send(PlayerEvent::Error {
                    message: format!("Invalid URI {}: {}", uri_str, e),
                });
            }
        }
    }

    fn handle_librespot_event(&mut self, event: LibrespotEvent) {
        match event {
            LibrespotEvent::Playing { position_ms, .. } => {
                if let Some(ref track) = self.current_track {
                    let _ = self.event_tx.send(PlayerEvent::Playing {
                        track: track.clone(),
                        position_ms,
                    });
                }
            }
            LibrespotEvent::Paused { position_ms, .. } => {
                if let Some(ref track) = self.current_track {
                    let _ = self.event_tx.send(PlayerEvent::Paused {
                        track: track.clone(),
                        position_ms,
                    });
                }
            }
            LibrespotEvent::Stopped { .. } => {
                let _ = self.event_tx.send(PlayerEvent::Stopped);
            }
            LibrespotEvent::TrackChanged { audio_item } => {
                let track_info = track_info_from_audio_item(&audio_item);
                self.current_track = Some(track_info.clone());
                let _ = self.event_tx.send(PlayerEvent::TrackChanged { track: track_info });
            }
            LibrespotEvent::EndOfTrack { .. } => {
                if self.queue_index + 1 < self.queue.len() {
                    self.queue_index += 1;
                    self.load_current_track(true);
                } else {
                    let _ = self.event_tx.send(PlayerEvent::EndOfTrack);
                }
            }
            LibrespotEvent::TimeToPreloadNextTrack { .. } => {
                if let Some(next_uri) = self.queue.get(self.queue_index + 1) {
                    if let Ok(uri) = SpotifyUri::from_uri(next_uri) {
                        self.player.preload(uri);
                    }
                }
            }
            LibrespotEvent::Unavailable { .. } => {
                let _ = self.event_tx.send(PlayerEvent::Error {
                    message: "Track unavailable in your region or account".to_string(),
                });
            }
            LibrespotEvent::Seeked { position_ms, .. } => {
                let _ = self.event_tx.send(PlayerEvent::PositionChanged { position_ms });
            }
            LibrespotEvent::PositionChanged { position_ms, .. } => {
                let _ = self.event_tx.send(PlayerEvent::PositionChanged { position_ms });
            }
            _ => {}
        }
    }
}

fn track_info_from_audio_item(item: &AudioItem) -> TrackInfo {
    use librespot_metadata::audio::UniqueFields;

    let (artist, album) = match &item.unique_fields {
        UniqueFields::Track {
            artists, album, ..
        } => {
            let artist_name = artists
                .0
                .first()
                .map(|a| a.name.clone())
                .unwrap_or_else(|| "Unknown".to_string());
            (artist_name, album.clone())
        }
        UniqueFields::Local { artists, album, .. } => (
            artists.clone().unwrap_or_else(|| "Unknown".to_string()),
            album.clone().unwrap_or_else(|| "Unknown".to_string()),
        ),
        UniqueFields::Episode { show_name, .. } => (show_name.clone(), String::new()),
    };

    TrackInfo {
        id: item.track_id.to_string(),
        title: item.name.clone(),
        artist,
        album,
        duration_ms: item.duration_ms,
    }
}
