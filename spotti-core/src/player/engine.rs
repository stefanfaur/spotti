use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;

use std::sync::mpsc as std_mpsc;

use crossbeam_channel::Sender;
use librespot_core::Session;
use librespot_core::SpotifyUri;
use librespot_core::authentication::Credentials;
use librespot_core::config::DeviceType;
use librespot_connect::{Spirc, ConnectConfig};
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
    spirc: Option<Spirc>,
    session: Session,
    credentials: Credentials,
    mixer: Arc<SoftMixer>,
    cmd_rx: mpsc::Receiver<PlayerCommand>,
    event_tx: Sender<PlayerEvent>,
    queue: Vec<String>,
    queue_index: usize,
    current_track: Option<TrackInfo>,
    is_playing: bool,
    shuffle: bool,
    repeat: RepeatMode,
    original_queue: Vec<String>,
    now_playing_tx: Option<std_mpsc::Sender<NowPlayingCommand>>,
    bitrate: Bitrate,
    consecutive_load_failures: u32,
    session_lost_emitted: bool,
}

impl PlayerEngine {
    pub async fn new(
        session: Session,
        credentials: Credentials,
        cmd_rx: mpsc::Receiver<PlayerCommand>,
        event_tx: Sender<PlayerEvent>,
        now_playing_tx: Option<std_mpsc::Sender<NowPlayingCommand>>,
    ) -> Result<(Self, Pin<Box<dyn Future<Output = ()> + Send>>), String> {
        let player_config = PlayerConfig {
            bitrate: Bitrate::Bitrate320,
            gapless: true,
            position_update_interval: Some(Duration::from_secs(1)),
            ..PlayerConfig::default()
        };

        let backend = audio_backend::find(None)
            .ok_or("No audio backend found (rodio expected)")?;
        let audio_format = AudioFormat::S16;

        let mixer = SoftMixer::open(MixerConfig::default())
            .map_err(|e| format!("Failed to create mixer: {}", e))?;
        let mixer = Arc::new(mixer);
        let volume_getter = mixer.get_soft_volume();

        let player = Player::new(
            player_config,
            session.clone(),
            volume_getter,
            move || backend(None, audio_format),
        );

        let connect_config = ConnectConfig {
            name: "Spotti".into(),
            device_type: DeviceType::Computer,
            is_group: false,
            initial_volume: 50 * 655, // ~50% in 0-65535 range
            disable_volume: false,
            volume_steps: 64,
            emit_set_queue_events: false,
        };

        // Spirc needs the Dealer WebSocket to be ready. The session may have
        // just connected to the AP, so retry a few times with a short delay.
        let mut spirc_result = None;
        for attempt in 0..3 {
            match Spirc::new(
                connect_config.clone(),
                session.clone(),
                credentials.clone(),
                player.clone(),
                mixer.clone(),
            )
            .await
            {
                Ok(result) => {
                    spirc_result = Some(result);
                    break;
                }
                Err(e) if attempt < 2 => {
                    log::warn!(
                        "Spirc creation attempt {} failed: {}, retrying...",
                        attempt + 1,
                        e
                    );
                    tokio::time::sleep(Duration::from_millis(500)).await;
                }
                Err(e) => {
                    return Err(format!(
                        "Failed to create Spirc after 3 attempts: {}",
                        e
                    ));
                }
            }
        }
        let (spirc, spirc_task) = spirc_result.unwrap();

        let engine = Self {
            player,
            spirc: Some(spirc),
            session,
            credentials,
            mixer,
            cmd_rx,
            event_tx,
            queue: Vec::new(),
            queue_index: 0,
            current_track: None,
            is_playing: false,
            shuffle: false,
            repeat: RepeatMode::Off,
            original_queue: Vec::new(),
            now_playing_tx,
            bitrate: Bitrate::Bitrate320,
            consecutive_load_failures: 0,
            session_lost_emitted: false,
        };

        let spirc_future: Pin<Box<dyn Future<Output = ()> + Send>> = Box::pin(spirc_task);
        Ok((engine, spirc_future))
    }

    fn update_now_playing(&self, cmd: NowPlayingCommand) {
        if let Some(ref tx) = self.now_playing_tx {
            let _ = tx.send(cmd);
        }
    }

    /// Main run loop. Call this from a spawned tokio task.
    pub async fn run(mut self, mut spirc_task: Pin<Box<dyn Future<Output = ()> + Send>>) {
        let mut event_channel = self.player.get_player_event_channel();
        let mut health_interval = tokio::time::interval(Duration::from_secs(5));

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
                        Some(cmd) => {
                            let should_exit = self.handle_command(cmd);
                            if should_exit { break; }
                        }
                        None => break,
                    }
                }
                _ = health_interval.tick() => {
                    self.check_session_health();
                }
                _ = &mut spirc_task => {
                    log::warn!("Spirc task exited — treating as session loss");
                    self.spirc = None;
                    if !self.session_lost_emitted {
                        self.session_lost_emitted = true;
                        self.is_playing = false;
                        let _ = self.event_tx.send(PlayerEvent::SessionLost {
                            message: "Spotify Connect disconnected".to_string(),
                        });
                    }
                    break;
                }
            }
        }
        if let Some(ref spirc) = self.spirc {
            let _ = spirc.shutdown();
        }
        self.player.stop();
    }

    /// Proactively detect session loss instead of waiting for load failures.
    fn check_session_health(&mut self) {
        if self.session.is_invalid() && !self.session_lost_emitted {
            log::warn!("Session health check: session is invalid");
            self.session_lost_emitted = true;
            self.is_playing = false;
            let _ = self.event_tx.send(PlayerEvent::SessionLost {
                message: "Session connection lost".to_string(),
            });
        }
    }

    /// Returns true if the run loop should exit.
    fn handle_command(&mut self, cmd: PlayerCommand) -> bool {
        match cmd {
            PlayerCommand::Play => {
                self.is_playing = true;
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.play();
                } else {
                    self.player.play();
                }
            }
            PlayerCommand::Pause => {
                self.is_playing = false;
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.pause();
                } else {
                    self.player.pause();
                }
            }
            PlayerCommand::Toggle => {
                log::info!("Toggle: is_playing={}", self.is_playing);
                if self.is_playing {
                    self.is_playing = false;
                    if let Some(ref spirc) = self.spirc {
                        let _ = spirc.pause();
                    } else {
                        self.player.pause();
                    }
                } else {
                    self.is_playing = true;
                    if let Some(ref spirc) = self.spirc {
                        let _ = spirc.play();
                    } else {
                        self.player.play();
                    }
                }
            }
            PlayerCommand::Stop => {
                self.is_playing = false;
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.pause();
                }
                self.player.stop();
            }
            PlayerCommand::Seek(pos_ms) => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.set_position_ms(pos_ms);
                } else {
                    self.player.seek(pos_ms);
                }
            }
            PlayerCommand::Next => {
                self.consecutive_load_failures = 0;
                if self.queue_index + 1 < self.queue.len() {
                    self.queue_index += 1;
                    self.load_current_track(true);
                }
            }
            PlayerCommand::Previous => {
                self.consecutive_load_failures = 0;
                if self.queue_index > 0 {
                    self.queue_index -= 1;
                    self.load_current_track(true);
                }
            }
            PlayerCommand::LoadTrack { uri, start_playing } => {
                self.consecutive_load_failures = 0;
                self.queue = vec![uri];
                self.queue_index = 0;
                self.load_current_track(start_playing);
            }
            PlayerCommand::LoadContext { uris, index } => {
                self.consecutive_load_failures = 0;
                self.queue = uris;
                self.queue_index = index;
                self.load_current_track(true);
            }
            PlayerCommand::SetVolume(volume) => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.set_volume(volume);
                } else {
                    self.mixer.set_volume(volume);
                }
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
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.shuffle(enabled);
                }
                let _ = self.event_tx.send(PlayerEvent::ShuffleChanged { enabled });
            }
            PlayerCommand::SetRepeat(mode) => {
                self.repeat = mode;
                if let Some(ref spirc) = self.spirc {
                    match mode {
                        RepeatMode::Off => {
                            let _ = spirc.repeat(false);
                            let _ = spirc.repeat_track(false);
                        }
                        RepeatMode::Context => {
                            let _ = spirc.repeat(true);
                            let _ = spirc.repeat_track(false);
                        }
                        RepeatMode::Track => {
                            let _ = spirc.repeat(false);
                            let _ = spirc.repeat_track(true);
                        }
                    }
                }
                let _ = self.event_tx.send(PlayerEvent::RepeatChanged { mode });
            }
            PlayerCommand::SetBitrate(level) => {
                self.bitrate = match level {
                    0 => Bitrate::Bitrate96,
                    1 => Bitrate::Bitrate160,
                    _ => Bitrate::Bitrate320,
                };
            }
            PlayerCommand::Shutdown => {
                log::info!("PlayerEngine shutting down");
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.shutdown();
                }
                self.player.stop();
                self.is_playing = false;
                return true;
            }
            PlayerCommand::Reconnect { session: new_session, credentials: new_credentials } => {
                log::info!("Hot-swapping session on existing player (is_playing={})", self.is_playing);
                self.session = new_session.clone();
                self.credentials = new_credentials;
                self.player.set_session(new_session);
                self.consecutive_load_failures = 0;
                self.session_lost_emitted = false;
                // Re-apply pause state: librespot's internal state machine may
                // transition to Playing after a session swap.
                if !self.is_playing {
                    self.player.pause();
                }
            }
        }
        false
    }

    fn load_current_track(&mut self, start_playing: bool) {
        let Some(uri_str) = self.queue.get(self.queue_index) else {
            return;
        };

        // Fail fast if session is already dead — don't waste time on doomed loads.
        if self.session.is_invalid() {
            if !self.session_lost_emitted {
                log::warn!("Session invalid at load time — emitting SessionLost");
                self.session_lost_emitted = true;
                self.is_playing = false;
                let _ = self.event_tx.send(PlayerEvent::SessionLost {
                    message: "Session connection lost".to_string(),
                });
            }
            return;
        }

        // Every load attempt increments the failure counter.
        // It is reset to 0 on successful Playing/TrackChanged events.
        self.consecutive_load_failures += 1;
        if self.consecutive_load_failures > 3 {
            log::error!(
                "Session lost: {} consecutive load attempts without success",
                self.consecutive_load_failures
            );
            let _ = self.event_tx.send(PlayerEvent::SessionLost {
                message: "Multiple consecutive track load failures — session may have expired".to_string(),
            });
            self.is_playing = false;
            return;
        }

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

    /// Advance the queue after a track fails to load, matching librespot's auto-skip behavior.
    fn advance_after_error(&mut self) {
        // Don't cascade: if we're already hitting consecutive failures, stop trying.
        if self.consecutive_load_failures > 2 {
            log::warn!("Stopping auto-advance: {} consecutive failures", self.consecutive_load_failures);
            return;
        }
        match self.repeat {
            RepeatMode::Track => {
                // Don't retry the same broken track in a loop
                if self.queue_index + 1 < self.queue.len() {
                    self.queue_index += 1;
                    self.load_current_track(true);
                } else {
                    let _ = self.event_tx.send(PlayerEvent::Stopped);
                }
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
                    let _ = self.event_tx.send(PlayerEvent::Stopped);
                }
            }
        }
    }

    fn handle_librespot_event(&mut self, event: LibrespotEvent) {
        match event {
            LibrespotEvent::Playing { position_ms, .. } => {
                self.is_playing = true;
                self.consecutive_load_failures = 0;
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
                self.is_playing = false;
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
                self.is_playing = false;
                let _ = self.event_tx.send(PlayerEvent::Stopped);
                self.update_now_playing(NowPlayingCommand::SetStopped);
            }
            LibrespotEvent::TrackChanged { audio_item } => {
                self.consecutive_load_failures = 0;
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
            LibrespotEvent::Unavailable { track_id, .. } => {
                let failed_id = track_id.to_string();
                let current_uri = self.queue.get(self.queue_index).cloned().unwrap_or_default();
                log::warn!("Track unavailable: {}", failed_id);

                // Only advance if the unavailable track is the one we're trying to play,
                // not a preloaded track that failed in the background.
                let is_current = current_uri.ends_with(&failed_id);
                if is_current {
                    let _ = self.event_tx.send(PlayerEvent::Error {
                        message: format!("Track unavailable: {}", current_uri),
                    });
                    self.advance_after_error();
                } else {
                    log::info!("Ignoring unavailable preload for {}, current is {}", failed_id, current_uri);
                }
            }
            LibrespotEvent::Seeked { position_ms, .. } => {
                let _ = self.event_tx.send(PlayerEvent::PositionChanged { position_ms });
                self.update_now_playing(NowPlayingCommand::UpdatePosition {
                    position_ms: position_ms as u32,
                    is_playing: self.is_playing,
                });
            }
            LibrespotEvent::PositionChanged { position_ms, .. } => {
                let _ = self.event_tx.send(PlayerEvent::PositionChanged { position_ms });
                self.update_now_playing(NowPlayingCommand::UpdatePosition {
                    position_ms: position_ms as u32,
                    is_playing: self.is_playing,
                });
            }
            LibrespotEvent::Loading { .. } => {
                // Librespot is loading a track. We already emit our own Loading event
                // from load_current_track, so we don't duplicate it here.
            }
            other => {
                log::debug!("Unhandled librespot event: {:?}", other);
            }
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

    let id_str = item.track_id.to_string();
    let uri = if id_str.starts_with("spotify:") {
        id_str.clone()
    } else {
        format!("spotify:track:{}", id_str)
    };

    TrackInfo {
        id: id_str,
        uri,
        title: item.name.clone(),
        artist,
        album,
        duration_ms: item.duration_ms,
        image_url,
    }
}
