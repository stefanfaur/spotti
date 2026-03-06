use std::sync::Arc;
use std::time::Duration;

use std::sync::mpsc as std_mpsc;

use crossbeam_channel::Sender;
use librespot_core::Session;
use librespot_core::SpotifyUri;
use librespot_metadata::audio::AudioItem;
use librespot_playback::audio_backend;
use librespot_playback::config::{AudioFormat, Bitrate, PlayerConfig};
use librespot_playback::mixer::{Mixer, MixerConfig};
use librespot_playback::mixer::softmixer::SoftMixer;
use librespot_playback::player::{Player, PlayerEvent as LibrespotEvent};
use tokio::sync::mpsc;

use crate::media::now_playing::NowPlayingCommand;
use super::types::{PlayerCommand, PlayerEvent, RepeatMode, TrackInfo};

pub struct PlayerEngine {
    player: Arc<Player>,
    mixer: Arc<SoftMixer>,
    cmd_rx: mpsc::Receiver<PlayerCommand>,
    event_tx: Sender<PlayerEvent>,
    queue: Vec<String>,
    queue_index: usize,
    current_track: Option<TrackInfo>,
    shuffle: bool,
    repeat: RepeatMode,
    original_queue: Vec<String>,
    now_playing_tx: Option<std_mpsc::Sender<NowPlayingCommand>>,
}

impl PlayerEngine {
    pub fn new(
        session: Session,
        cmd_rx: mpsc::Receiver<PlayerCommand>,
        event_tx: Sender<PlayerEvent>,
        now_playing_tx: Option<std_mpsc::Sender<NowPlayingCommand>>,
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

        let mixer = SoftMixer::open(MixerConfig::default())
            .map_err(|e| format!("Failed to create mixer: {}", e))?;
        let mixer = Arc::new(mixer);
        let volume_getter = mixer.get_soft_volume();

        let player = Player::new(
            player_config,
            session,
            volume_getter,
            move || backend(None, audio_format),
        );

        Ok(Self {
            player,
            mixer,
            cmd_rx,
            event_tx,
            queue: Vec::new(),
            queue_index: 0,
            current_track: None,
            shuffle: false,
            repeat: RepeatMode::Off,
            original_queue: Vec::new(),
            now_playing_tx,
        })
    }

    fn update_now_playing(&self, cmd: NowPlayingCommand) {
        if let Some(ref tx) = self.now_playing_tx {
            let _ = tx.send(cmd);
        }
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
            PlayerCommand::SetVolume(volume) => {
                self.mixer.set_volume(volume);
                let _ = self.event_tx.send(PlayerEvent::VolumeChanged { volume });
            }
            PlayerCommand::SetShuffle(enabled) => {
                self.shuffle = enabled;
                if enabled {
                    self.original_queue = self.queue.clone();
                    let current_uri = self.queue.get(self.queue_index).cloned();
                    let mut rest: Vec<String> = self
                        .queue
                        .iter()
                        .enumerate()
                        .filter(|(i, _)| *i != self.queue_index)
                        .map(|(_, uri)| uri.clone())
                        .collect();
                    use rand::seq::SliceRandom;
                    rest.shuffle(&mut rand::rng());
                    self.queue = Vec::with_capacity(rest.len() + 1);
                    if let Some(current) = current_uri {
                        self.queue.push(current);
                    }
                    self.queue.extend(rest);
                    self.queue_index = 0;
                } else if !self.original_queue.is_empty() {
                    let current_uri = self.queue.first().cloned();
                    self.queue = self.original_queue.clone();
                    if let Some(ref uri) = current_uri {
                        self.queue_index = self
                            .original_queue
                            .iter()
                            .position(|u| u == uri)
                            .unwrap_or(0);
                    }
                }
                let _ = self.event_tx.send(PlayerEvent::ShuffleChanged { enabled });
            }
            PlayerCommand::SetRepeat(mode) => {
                self.repeat = mode;
                let _ = self.event_tx.send(PlayerEvent::RepeatChanged { mode });
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
                    self.update_now_playing(NowPlayingCommand::SetPlaying {
                        position_ms: position_ms as u32,
                    });
                }
            }
            LibrespotEvent::Paused { position_ms, .. } => {
                if let Some(ref track) = self.current_track {
                    let _ = self.event_tx.send(PlayerEvent::Paused {
                        track: track.clone(),
                        position_ms,
                    });
                    self.update_now_playing(NowPlayingCommand::SetPaused {
                        position_ms: position_ms as u32,
                    });
                }
            }
            LibrespotEvent::Stopped { .. } => {
                let _ = self.event_tx.send(PlayerEvent::Stopped);
                self.update_now_playing(NowPlayingCommand::SetStopped);
            }
            LibrespotEvent::TrackChanged { audio_item } => {
                let track_info = track_info_from_audio_item(&audio_item);
                self.current_track = Some(track_info.clone());
                let _ = self.event_tx.send(PlayerEvent::TrackChanged { track: track_info.clone() });
                self.update_now_playing(NowPlayingCommand::SetMetadata {
                    title: track_info.title,
                    artist: track_info.artist,
                    album: track_info.album,
                    cover_url: None, // souvlaki macOS needs file:// URLs; art cache integration later
                    duration_ms: track_info.duration_ms,
                });
            }
            LibrespotEvent::EndOfTrack { .. } => {
                match self.repeat {
                    RepeatMode::Track => {
                        self.load_current_track(true);
                    }
                    RepeatMode::Context => {
                        self.queue_index += 1;
                        if self.queue_index >= self.queue.len() {
                            self.queue_index = 0;
                        }
                        self.load_current_track(true);
                    }
                    RepeatMode::Off => {
                        if self.queue_index + 1 < self.queue.len() {
                            self.queue_index += 1;
                            self.load_current_track(true);
                        } else {
                            let _ = self.event_tx.send(PlayerEvent::EndOfTrack);
                        }
                    }
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
                self.update_now_playing(NowPlayingCommand::UpdatePosition {
                    position_ms: position_ms as u32,
                });
            }
            LibrespotEvent::PositionChanged { position_ms, .. } => {
                let _ = self.event_tx.send(PlayerEvent::PositionChanged { position_ms });
                self.update_now_playing(NowPlayingCommand::UpdatePosition {
                    position_ms: position_ms as u32,
                });
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

    let image_url = item.covers.first().map(|c| c.url.clone());

    TrackInfo {
        id: item.track_id.to_string(),
        title: item.name.clone(),
        artist,
        album,
        duration_ms: item.duration_ms,
        image_url,
    }
}
