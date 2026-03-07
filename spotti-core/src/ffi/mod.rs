use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use crossbeam_channel::bounded;
use tokio::sync::mpsc;

use crate::cache::art::ArtCache;
use crate::media::now_playing::{spawn_now_playing_service, MediaControlAction};
use crate::player::types::RepeatMode;
use crate::player::{PlayerCommand, PlayerEvent, PlayerEngine};
use crate::runtime::get_runtime;
use crate::spotify::auth::AuthManager;
use rspotify::clients::OAuthClient;

/// Callback type for player events.
/// `event_json` is a JSON string describing the event.
/// Called from a background thread — dispatch to main thread in Swift.
pub type SpottiEventCallback = extern "C" fn(event_json: *const c_char);

/// Opaque handle to the Spotti core instance.
pub struct SpottiCore {
    auth: Option<AuthManager>,
    client_id: String,
    cmd_tx: Option<mpsc::Sender<PlayerCommand>>,
    event_callback: Option<SpottiEventCallback>,
    art_cache: Option<ArtCache>,
    sync_task: Option<tokio::task::JoinHandle<()>>,
    sync_running: std::sync::Arc<std::sync::atomic::AtomicBool>,
}

/// Helper to emit an event directly via FFI callback (outside the crossbeam channel path).
unsafe fn emit_event(callback: Option<SpottiEventCallback>, event: &PlayerEvent) {
    if let Some(cb) = callback {
        if let Ok(json) = serde_json::to_string(event) {
            if let Ok(c_str) = CString::new(json) {
                cb(c_str.as_ptr());
            }
        }
    }
}

// ── Lifecycle ──

/// Initialize the Spotti core with a Spotify client ID.
/// `client_id` must be a valid null-terminated C string.
/// Returns an opaque pointer that must be freed with `spotti_core_destroy`.
#[no_mangle]
pub extern "C" fn spotti_core_create(client_id: *const c_char) -> *mut SpottiCore {
    env_logger::try_init().ok();

    let client_id = unsafe { CStr::from_ptr(client_id) }
        .to_string_lossy()
        .into_owned();

    let core = SpottiCore {
        auth: None,
        client_id,
        cmd_tx: None,
        event_callback: None,
        art_cache: None,
        sync_task: None,
        sync_running: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
    };
    Box::into_raw(Box::new(core))
}

/// Destroy the Spotti core and free all resources.
#[no_mangle]
pub extern "C" fn spotti_core_destroy(core: *mut SpottiCore) {
    if !core.is_null() {
        unsafe { drop(Box::from_raw(core)) };
    }
}

// ── Event Callback ──

/// Register a callback for player events.
#[no_mangle]
pub extern "C" fn spotti_set_event_callback(
    core: *mut SpottiCore,
    callback: SpottiEventCallback,
) {
    let core = unsafe { &mut *core };
    core.event_callback = Some(callback);
}

// ── Authentication ──

/// Authenticate with Spotify. Opens browser on first run.
/// Returns 0 on success, -1 on failure.
#[no_mangle]
pub extern "C" fn spotti_authenticate(core: *mut SpottiCore) -> i32 {
    let core = unsafe { &mut *core };
    let mut auth = AuthManager::new(core.client_id.clone());

    match get_runtime().block_on(auth.authenticate()) {
        Ok(()) => {
            core.auth = Some(auth);
            core.art_cache = ArtCache::new().ok();
            0
        }
        Err(e) => {
            log::error!("Authentication failed: {}", e);
            -1
        }
    }
}

// ── Player Initialization ──

/// Initialize the player engine after successful authentication.
/// Returns 0 on success, -1 on failure.
#[no_mangle]
pub extern "C" fn spotti_player_init(core: *mut SpottiCore) -> i32 {
    let core = unsafe { &mut *core };

    let session = match core.auth.as_ref().and_then(|a| a.session()) {
        Some(s) => s.clone(),
        None => {
            log::error!("Cannot init player: not authenticated");
            return -1;
        }
    };

    let (cmd_tx, cmd_rx) = mpsc::channel::<PlayerCommand>(64);
    let (event_tx, event_rx) = bounded::<PlayerEvent>(64);

    let callback = core.event_callback;

    // Spawn Now Playing service (media keys + Now Playing widget)
    let media_cmd_tx = cmd_tx.clone();
    let now_playing_tx = match spawn_now_playing_service(move |action| {
        let cmd = match action {
            MediaControlAction::Play => PlayerCommand::Play,
            MediaControlAction::Pause => PlayerCommand::Pause,
            MediaControlAction::Toggle => PlayerCommand::Toggle,
            MediaControlAction::Next => PlayerCommand::Next,
            MediaControlAction::Previous => PlayerCommand::Previous,
            MediaControlAction::Stop => PlayerCommand::Stop,
            MediaControlAction::SeekTo(ms) => PlayerCommand::Seek(ms),
        };
        let _ = media_cmd_tx.blocking_send(cmd);
    }) {
        Ok(tx) => Some(tx),
        Err(e) => {
            log::warn!("Now Playing service unavailable: {e}");
            None
        }
    };

    // Spawn the player engine on the tokio runtime
    get_runtime().spawn(async move {
        match PlayerEngine::new(session, cmd_rx, event_tx, now_playing_tx) {
            Ok(engine) => engine.run().await,
            Err(e) => log::error!("PlayerEngine failed to start: {}", e),
        }
    });

    // Spawn event dispatch thread (calls Swift callback)
    if let Some(cb) = callback {
        std::thread::spawn(move || {
            while let Ok(event) = event_rx.recv() {
                if let Ok(json) = serde_json::to_string(&event) {
                    if let Ok(c_str) = CString::new(json) {
                        cb(c_str.as_ptr());
                    }
                }
            }
        });
    }

    core.cmd_tx = Some(cmd_tx);
    0
}

// ── Playback Commands ──

fn send_cmd(core: *mut SpottiCore, cmd: PlayerCommand) {
    let core = unsafe { &*core };
    if let Some(ref tx) = core.cmd_tx {
        let _ = tx.blocking_send(cmd);
    }
}

#[no_mangle]
pub extern "C" fn spotti_play(core: *mut SpottiCore) {
    send_cmd(core, PlayerCommand::Play);
}

#[no_mangle]
pub extern "C" fn spotti_pause(core: *mut SpottiCore) {
    send_cmd(core, PlayerCommand::Pause);
}

#[no_mangle]
pub extern "C" fn spotti_stop(core: *mut SpottiCore) {
    send_cmd(core, PlayerCommand::Stop);
}

#[no_mangle]
pub extern "C" fn spotti_next(core: *mut SpottiCore) {
    send_cmd(core, PlayerCommand::Next);
}

#[no_mangle]
pub extern "C" fn spotti_previous(core: *mut SpottiCore) {
    send_cmd(core, PlayerCommand::Previous);
}

#[no_mangle]
pub extern "C" fn spotti_seek(core: *mut SpottiCore, position_ms: u32) {
    send_cmd(core, PlayerCommand::Seek(position_ms));
}

/// Load and play a single track by Spotify URI.
/// `uri` must be a null-terminated C string like "spotify:track:4uLU6hMCjMI75M1A2tKUQC".
#[no_mangle]
pub extern "C" fn spotti_load_track(core: *mut SpottiCore, uri: *const c_char) {
    let uri = unsafe { CStr::from_ptr(uri) }
        .to_string_lossy()
        .into_owned();
    send_cmd(core, PlayerCommand::LoadTrack {
        uri,
        start_playing: true,
    });
}

/// Load multiple tracks as a queue. `uris_json` is a JSON array of URI strings.
/// `index` is the starting track index.
#[no_mangle]
pub extern "C" fn spotti_load_context(
    core: *mut SpottiCore,
    uris_json: *const c_char,
    index: u32,
) {
    let json_str = unsafe { CStr::from_ptr(uris_json) }
        .to_string_lossy()
        .into_owned();

    if let Ok(uris) = serde_json::from_str::<Vec<String>>(&json_str) {
        send_cmd(core, PlayerCommand::LoadContext {
            uris,
            index: index as usize,
        });
    }
}

// ── Bitrate ──

/// Set audio quality. 0 = Low (96kbps), 1 = Normal (160kbps), 2 = High (320kbps).
/// Takes effect on next track load.
#[no_mangle]
pub extern "C" fn spotti_set_bitrate(core: *mut SpottiCore, level: u32) {
    send_cmd(core, PlayerCommand::SetBitrate(level));
}

// ── Volume, Shuffle, Repeat ──

/// Set volume (0-100 range, mapped to 0-65535 internally)
#[no_mangle]
pub extern "C" fn spotti_set_volume(core: *mut SpottiCore, volume: u32) {
    let mapped = ((volume.min(100) as u64 * 65535) / 100) as u16;
    send_cmd(core, PlayerCommand::SetVolume(mapped));
}

/// Set shuffle on/off
#[no_mangle]
pub extern "C" fn spotti_set_shuffle(core: *mut SpottiCore, enabled: bool) {
    send_cmd(core, PlayerCommand::SetShuffle(enabled));
}

/// Set repeat mode: 0 = off, 1 = context, 2 = track
#[no_mangle]
pub extern "C" fn spotti_set_repeat(core: *mut SpottiCore, mode: u32) {
    let repeat_mode = match mode {
        1 => RepeatMode::Context,
        2 => RepeatMode::Track,
        _ => RepeatMode::Off,
    };
    send_cmd(core, PlayerCommand::SetRepeat(repeat_mode));
}

// ── Search, Library, Detail ──

/// Search Spotify. Results arrive via SearchResults event.
#[no_mangle]
pub unsafe extern "C" fn spotti_search(
    core: *mut SpottiCore,
    query: *const c_char,
    offset: u32,
) {
    let core = &*core;
    let query = CStr::from_ptr(query).to_string_lossy().to_string();

    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            get_runtime().spawn(async move {
                match crate::spotify::search::search(&client, &query, offset).await {
                    Ok(results) => {
                        if let Ok(json) = serde_json::to_string(&results) {
                            emit_event(
                                event_cb,
                                &PlayerEvent::SearchResults {
                                    results_json: json,
                                },
                            );
                        }
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: e.to_string(),
                            },
                        );
                    }
                }
            });
        }
    }
}

/// Fetch user library. Results arrive via LibraryContent event.
#[no_mangle]
pub unsafe extern "C" fn spotti_fetch_library(core: *mut SpottiCore) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            get_runtime().spawn(async move {
                match crate::spotify::library::fetch_library(&client).await {
                    Ok(content) => {
                        if let Ok(json) = serde_json::to_string(&content) {
                            emit_event(
                                event_cb,
                                &PlayerEvent::LibraryContent {
                                    content_json: json,
                                },
                            );
                        }
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: e.to_string(),
                            },
                        );
                    }
                }
            });
        }
    }
}

/// Fetch playlist detail. Results arrive via PlaylistDetail event.
#[no_mangle]
pub unsafe extern "C" fn spotti_fetch_playlist(
    core: *mut SpottiCore,
    playlist_id: *const c_char,
) {
    let core = &*core;
    let playlist_id = CStr::from_ptr(playlist_id).to_string_lossy().to_string();
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            get_runtime().spawn(async move {
                match crate::spotify::detail::fetch_playlist(&client, &playlist_id).await {
                    Ok(detail) => {
                        if let Ok(json) = serde_json::to_string(&detail) {
                            emit_event(
                                event_cb,
                                &PlayerEvent::PlaylistDetail { detail_json: json },
                            );
                        }
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: e.to_string(),
                            },
                        );
                    }
                }
            });
        }
    }
}

/// Fetch album detail. Results arrive via AlbumDetail event.
#[no_mangle]
pub unsafe extern "C" fn spotti_fetch_album(
    core: *mut SpottiCore,
    album_id: *const c_char,
) {
    let core = &*core;
    let album_id = CStr::from_ptr(album_id).to_string_lossy().to_string();
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            get_runtime().spawn(async move {
                match crate::spotify::detail::fetch_album(&client, &album_id).await {
                    Ok(detail) => {
                        if let Ok(json) = serde_json::to_string(&detail) {
                            emit_event(
                                event_cb,
                                &PlayerEvent::AlbumDetail { detail_json: json },
                            );
                        }
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: e.to_string(),
                            },
                        );
                    }
                }
            });
        }
    }
}

/// Fetch artist detail. Results arrive via ArtistDetail event.
#[no_mangle]
pub unsafe extern "C" fn spotti_fetch_artist(
    core: *mut SpottiCore,
    artist_id: *const c_char,
) {
    let core = &*core;
    let artist_id = CStr::from_ptr(artist_id).to_string_lossy().to_string();
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            get_runtime().spawn(async move {
                match crate::spotify::detail::fetch_artist(&client, &artist_id).await {
                    Ok(detail) => {
                        if let Ok(json) = serde_json::to_string(&detail) {
                            emit_event(
                                event_cb,
                                &PlayerEvent::ArtistDetail { detail_json: json },
                            );
                        }
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: e.to_string(),
                            },
                        );
                    }
                }
            });
        }
    }
}

// ── Devices (Spotify Connect) ──

/// Fetch available Spotify Connect devices. Results arrive via DeviceList event.
#[no_mangle]
pub unsafe extern "C" fn spotti_fetch_devices(core: *mut SpottiCore) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            get_runtime().spawn(async move {
                match crate::spotify::devices::fetch_devices(&client).await {
                    Ok(devices) => {
                        if let Ok(json) = serde_json::to_string(&devices) {
                            emit_event(
                                event_cb,
                                &PlayerEvent::DeviceList { devices_json: json },
                            );
                        }
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: format!("Device fetch failed: {e}"),
                            },
                        );
                    }
                }
            });
        }
    }
}

/// Transfer playback to a specific device.
#[no_mangle]
pub unsafe extern "C" fn spotti_transfer_playback(
    core: *mut SpottiCore,
    device_id: *const c_char,
    start_playing: bool,
) {
    let core = &*core;
    let device_id = CStr::from_ptr(device_id).to_string_lossy().to_string();
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            let event_cb = core.event_callback;
            let did = device_id.clone();
            get_runtime().spawn(async move {
                match crate::spotify::devices::transfer_playback(&client, &did, start_playing)
                    .await
                {
                    Ok(()) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::DeviceTransferred { device_id: did },
                        );
                    }
                    Err(e) => {
                        emit_event(
                            event_cb,
                            &PlayerEvent::Error {
                                message: format!("Device transfer failed: {e}"),
                            },
                        );
                    }
                }
            });
        }
    }
}

// ── Account ──

/// Get the authenticated username. Returns a C string that must be freed with `spotti_free_string`.
/// Returns null if not authenticated.
#[no_mangle]
pub extern "C" fn spotti_get_username(core: *mut SpottiCore) -> *mut c_char {
    let core = unsafe { &*core };
    match core.auth.as_ref().and_then(|a| a.username()) {
        Some(name) => match CString::new(name) {
            Ok(c_str) => c_str.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        None => std::ptr::null_mut(),
    }
}

/// Get our librespot device ID. Returns a C string freed with `spotti_free_string`.
/// Returns null if not authenticated.
#[no_mangle]
pub extern "C" fn spotti_get_device_id(core: *mut SpottiCore) -> *mut c_char {
    let core = unsafe { &*core };
    match core.auth.as_ref().and_then(|a| a.session()).map(|s| s.device_id().to_string()) {
        Some(id) => match CString::new(id) {
            Ok(c_str) => c_str.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        None => std::ptr::null_mut(),
    }
}

/// Free a string returned by spotti_get_username.
#[no_mangle]
pub extern "C" fn spotti_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

// ── Cache Info ──

/// Query art cache size. Result arrives via CacheInfo event.
#[no_mangle]
pub extern "C" fn spotti_cache_info(core: *mut SpottiCore) {
    let core = unsafe { &*core };
    if let Some(ref cache) = core.art_cache {
        let size_bytes = cache.cache_size_bytes();
        let item_count = cache.item_count() as u32;
        unsafe {
            emit_event(
                core.event_callback,
                &PlayerEvent::CacheInfo { size_bytes, item_count },
            );
        }
    }
}

/// Clear all cached art. Emits CacheCleared event when done.
#[no_mangle]
pub extern "C" fn spotti_clear_cache(core: *mut SpottiCore) {
    let core = unsafe { &*core };
    if let Some(ref cache) = core.art_cache {
        let _ = cache.clear();
        unsafe {
            emit_event(core.event_callback, &PlayerEvent::CacheCleared);
        }
    }
}

// ── Playback Sync ──

/// Start background playback sync. Polls Spotify Web API every 5s.
/// Emits PlaybackSynced events. Safe to call multiple times (cancels previous task).
#[no_mangle]
pub extern "C" fn spotti_start_playback_sync(core: *mut SpottiCore) {
    let core = unsafe { &mut *core };

    // Cancel any existing sync task
    if let Some(handle) = core.sync_task.take() {
        core.sync_running.store(false, std::sync::atomic::Ordering::SeqCst);
        handle.abort();
    }

    let running = core.sync_running.clone();
    running.store(true, std::sync::atomic::Ordering::SeqCst);

    let client = match core.auth.as_ref().and_then(|a| a.rspotify()).cloned() {
        Some(c) => c,
        None => {
            log::warn!("Cannot start sync: not authenticated");
            return;
        }
    };

    let our_device_id: Option<String> = core.auth.as_ref()
        .and_then(|a| a.session())
        .map(|s| s.device_id().to_string());

    let event_cb = core.event_callback;

    let handle = get_runtime().spawn(async move {
        loop {
            if !running.load(std::sync::atomic::Ordering::SeqCst) {
                break;
            }
            match crate::spotify::playback_sync::fetch_current_playback(&client).await {
                Ok(state_opt) => {
                    let event = match state_opt {
                        Some(state) => {
                            let is_our = state.device_id.as_deref()
                                .zip(our_device_id.as_deref())
                                .map(|(did, ours)| did == ours)
                                .unwrap_or(false);
                            PlayerEvent::PlaybackSynced {
                                track: state.track,
                                is_playing: state.is_playing,
                                position_ms: state.position_ms,
                                device_id: state.device_id,
                                device_name: state.device_name,
                                shuffle: state.shuffle,
                                repeat: state.repeat,
                                is_our_device: is_our,
                            }
                        }
                        None => PlayerEvent::PlaybackSynced {
                            track: None,
                            is_playing: false,
                            position_ms: 0,
                            device_id: None,
                            device_name: None,
                            shuffle: false,
                            repeat: crate::player::types::RepeatMode::Off,
                            is_our_device: false,
                        },
                    };
                    unsafe { emit_event(event_cb, &event) };
                }
                Err(e) => {
                    log::warn!("Playback sync error: {e}");
                }
            }
            tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        }
    });

    core.sync_task = Some(handle);
}

/// Stop background playback sync.
#[no_mangle]
pub extern "C" fn spotti_stop_playback_sync(core: *mut SpottiCore) {
    let core = unsafe { &mut *core };
    core.sync_running.store(false, std::sync::atomic::Ordering::SeqCst);
    if let Some(handle) = core.sync_task.take() {
        handle.abort();
    }
}

// ── Session Reconnection ──

/// Reconnect after session loss. Drops old player, re-authenticates with
/// cached credentials, and reinitializes the player + playback sync.
/// Returns 0 on success, -1 on failure.
#[no_mangle]
pub extern "C" fn spotti_reconnect(core: *mut SpottiCore) -> i32 {
    {
        let core = unsafe { &mut *core };

        // Stop playback sync
        core.sync_running.store(false, std::sync::atomic::Ordering::SeqCst);
        if let Some(handle) = core.sync_task.take() {
            handle.abort();
        }

        // Gracefully shut down the old player engine before dropping the channel.
        // This ensures the librespot Player calls stop() and releases audio resources.
        if let Some(ref tx) = core.cmd_tx {
            let _ = tx.blocking_send(PlayerCommand::Shutdown);
            // Give the engine a moment to process Shutdown and stop audio output
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        core.cmd_tx = None;

        // Re-authenticate with cached credentials
        let mut auth = AuthManager::new(core.client_id.clone());
        match get_runtime().block_on(auth.authenticate()) {
            Ok(()) => {
                log::info!("Session reconnected successfully");
                core.auth = Some(auth);
            }
            Err(e) => {
                log::error!("Reconnection failed: {}", e);
                return -1;
            }
        }
    }
    // Mutable borrow dropped — safe to call FFI functions with raw pointer

    let result = spotti_player_init(core);
    if result == 0 {
        spotti_start_playback_sync(core);
    }
    result
}

// ── Web API Playback Control ──
// These functions control playback on the currently active Spotify device
// via the Web API. Used when in external/passive mode.

/// Resume playback on the currently active device via Web API.
#[no_mangle]
pub unsafe extern "C" fn spotti_web_play(core: *mut SpottiCore) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            get_runtime().spawn(async move {
                if let Err(e) = client.resume_playback(None, None).await {
                    log::warn!("web_play failed: {e}");
                }
            });
        }
    }
}

/// Pause playback on the currently active device via Web API.
#[no_mangle]
pub unsafe extern "C" fn spotti_web_pause(core: *mut SpottiCore) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            get_runtime().spawn(async move {
                if let Err(e) = client.pause_playback(None).await {
                    log::warn!("web_pause failed: {e}");
                }
            });
        }
    }
}

/// Skip to next track on the currently active device via Web API.
#[no_mangle]
pub unsafe extern "C" fn spotti_web_next(core: *mut SpottiCore) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            get_runtime().spawn(async move {
                if let Err(e) = client.next_track(None).await {
                    log::warn!("web_next failed: {e}");
                }
            });
        }
    }
}

/// Skip to previous track on the currently active device via Web API.
#[no_mangle]
pub unsafe extern "C" fn spotti_web_previous(core: *mut SpottiCore) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            get_runtime().spawn(async move {
                if let Err(e) = client.previous_track(None).await {
                    log::warn!("web_previous failed: {e}");
                }
            });
        }
    }
}

/// Seek on the currently active device via Web API.
#[no_mangle]
pub unsafe extern "C" fn spotti_web_seek(core: *mut SpottiCore, position_ms: u32) {
    let core = &*core;
    if let Some(auth) = &core.auth {
        if let Some(client) = auth.rspotify() {
            let client = client.clone();
            get_runtime().spawn(async move {
                let pos = chrono::Duration::milliseconds(position_ms as i64);
                if let Err(e) = client.seek_track(pos, None).await {
                    log::warn!("web_seek failed: {e}");
                }
            });
        }
    }
}

// ── Art Cache ──

/// Cache album art. Result arrives via ArtCached event with local file path.
#[no_mangle]
pub unsafe extern "C" fn spotti_cache_art(
    core: *mut SpottiCore,
    id: *const c_char,
    url: *const c_char,
) {
    let core = &*core;
    let id = CStr::from_ptr(id).to_string_lossy().to_string();
    let url = CStr::from_ptr(url).to_string_lossy().to_string();

    if let Some(art_cache) = &core.art_cache {
        // Check disk cache first (synchronous)
        if let Some(path) = art_cache.cached_path(&id) {
            emit_event(
                core.event_callback,
                &PlayerEvent::ArtCached {
                    id,
                    path,
                },
            );
            return;
        }

        let event_cb = core.event_callback;
        get_runtime().spawn(async move {
            if let Ok(cache) = ArtCache::new() {
                match cache.get_or_download(&id, &url).await {
                    Ok(path) => {
                        emit_event(event_cb, &PlayerEvent::ArtCached { id, path });
                    }
                    Err(e) => {
                        log::warn!("Art cache failed for {}: {}", id, e);
                    }
                }
            }
        });
    }
}
