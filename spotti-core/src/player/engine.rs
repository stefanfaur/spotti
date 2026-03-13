use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;

use std::sync::mpsc as std_mpsc;

use crossbeam_channel::Sender;
use librespot_core::Session;
use librespot_core::authentication::Credentials;
use librespot_core::config::DeviceType;
use librespot_connect::{Spirc, ConnectConfig, LoadRequest, LoadRequestOptions, PlayingTrack};
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
    current_track: Option<TrackInfo>,
    is_playing: bool,
    now_playing_tx: Option<std_mpsc::Sender<NowPlayingCommand>>,
    bitrate: Bitrate,
    session_lost_emitted: bool,
    activated: bool,
}

impl PlayerEngine {
    pub async fn new(
        playback_session: Session,
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
            playback_session.clone(),
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

        let (spirc, spirc_task) = Spirc::new(
            connect_config,
            playback_session.clone(),
            credentials.clone(),
            player.clone(),
            mixer.clone(),
        )
        .await
        .map_err(|e| format!("Failed to create Spirc: {}", e))?;

        let engine = Self {
            player,
            spirc: Some(spirc),
            session: playback_session,
            credentials,
            mixer,
            cmd_rx,
            event_tx,
            current_track: None,
            is_playing: false,
            now_playing_tx,
            bitrate: Bitrate::Bitrate320,
            session_lost_emitted: false,
            activated: false,
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

    fn ensure_active(&mut self) {
        if !self.activated {
            if let Some(ref spirc) = self.spirc {
                let _ = spirc.activate();
                self.activated = true;
            }
        }
    }

    /// Returns true if the run loop should exit.
    fn handle_command(&mut self, cmd: PlayerCommand) -> bool {
        match cmd {
            PlayerCommand::Play => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.play();
                }
            }
            PlayerCommand::Pause => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.pause();
                }
            }
            PlayerCommand::Toggle => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.play_pause();
                }
            }
            PlayerCommand::Stop => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.pause();
                }
            }
            PlayerCommand::Seek(pos_ms) => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.set_position_ms(pos_ms);
                }
            }
            PlayerCommand::Next => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.next();
                }
            }
            PlayerCommand::Previous => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.prev();
                }
            }
            PlayerCommand::LoadTrack { uri, start_playing } => {
                self.ensure_active();
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.load(LoadRequest::from_tracks(
                        vec![uri],
                        LoadRequestOptions {
                            start_playing,
                            ..Default::default()
                        },
                    ));
                }
            }
            PlayerCommand::LoadContext { uris, index } => {
                self.ensure_active();
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.load(LoadRequest::from_tracks(
                        uris,
                        LoadRequestOptions {
                            start_playing: true,
                            playing_track: Some(PlayingTrack::Index(index as u32)),
                            ..Default::default()
                        },
                    ));
                }
            }
            PlayerCommand::LoadContextUri { context_uri, track_uri, position_ms } => {
                self.ensure_active();
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.load(LoadRequest::from_context_uri(
                        context_uri,
                        LoadRequestOptions {
                            start_playing: true,
                            seek_to: position_ms,
                            playing_track: track_uri.map(PlayingTrack::Uri),
                            ..Default::default()
                        },
                    ));
                }
            }
            PlayerCommand::SetVolume(volume) => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.set_volume(volume);
                }
                let _ = self.event_tx.send(PlayerEvent::VolumeChanged { volume });
            }
            PlayerCommand::SetShuffle(enabled) => {
                if let Some(ref spirc) = self.spirc {
                    let _ = spirc.shuffle(enabled);
                }
                let _ = self.event_tx.send(PlayerEvent::ShuffleChanged { enabled });
            }
            PlayerCommand::SetRepeat(mode) => {
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
        }
        false
    }

    fn handle_librespot_event(&mut self, event: LibrespotEvent) {
        match event {
            LibrespotEvent::Playing { position_ms, .. } => {
                self.is_playing = true;
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
                let track_info = track_info_from_audio_item(&audio_item);
                self.current_track = Some(track_info.clone());
                let _ = self.event_tx.send(PlayerEvent::TrackChanged { track: track_info.clone() });
                self.update_now_playing(NowPlayingCommand::SetMetadata {
                    title: track_info.title,
                    artist: track_info.artist,
                    album: track_info.album,
                    cover_url: None,
                    duration_ms: track_info.duration_ms,
                });
            }
            LibrespotEvent::EndOfTrack { .. } => {
                // Spirc handles queue advancement internally.
                // We'll get TrackChanged + Playing events for the next track.
            }
            LibrespotEvent::TimeToPreloadNextTrack { .. } => {
                // Spirc handles preloading internally.
            }
            LibrespotEvent::Unavailable { track_id, .. } => {
                log::warn!("Track unavailable: {}", track_id);
                let _ = self.event_tx.send(PlayerEvent::Error {
                    message: format!("Track unavailable: {}", track_id),
                });
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
            LibrespotEvent::Loading { track_id, .. } => {
                let _ = self.event_tx.send(PlayerEvent::Loading {
                    uri: track_id.to_string(),
                });
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
