use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use crossbeam_channel::bounded;
use tokio::sync::mpsc;

use crate::cache::art::ArtCache;
use crate::player::types::RepeatMode;
use crate::player::{PlayerCommand, PlayerEvent, PlayerEngine};
use crate::runtime::get_runtime;
use crate::spotify::auth::AuthManager;

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

    // Spawn the player engine on the tokio runtime
    get_runtime().spawn(async move {
        match PlayerEngine::new(session, cmd_rx, event_tx) {
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
