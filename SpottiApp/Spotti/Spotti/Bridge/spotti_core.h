#ifndef SPOTTI_CORE_H
#define SPOTTI_CORE_H

#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

/**
 * Opaque handle to the Spotti core instance.
 */
typedef struct SpottiCore SpottiCore;

/**
 * Callback type for player events.
 * `event_json` is a JSON string describing the event.
 * Called from a background thread — dispatch to main thread in Swift.
 */
typedef void (*SpottiEventCallback)(const char *event_json);

/**
 * Initialize the Spotti core with a Spotify client ID.
 * `client_id` must be a valid null-terminated C string.
 * Returns an opaque pointer that must be freed with `spotti_core_destroy`.
 */
struct SpottiCore *spotti_core_create(const char *client_id);

/**
 * Set the Last.fm API key used for radio features.
 * Must be called before any radio functions are invoked.
 */
void spotti_set_lastfm_api_key(struct SpottiCore *core, const char *api_key);

/**
 * Destroy the Spotti core and free all resources.
 */
void spotti_core_destroy(struct SpottiCore *core);

/**
 * Register a callback for player events.
 */
void spotti_set_event_callback(struct SpottiCore *core, SpottiEventCallback callback);

/**
 * Authenticate with Spotify. Opens browser on first run.
 * Returns 0 on success, -1 on failure.
 */
int32_t spotti_authenticate(struct SpottiCore *core);

/**
 * Initialize the player engine after successful authentication.
 * Returns 0 on success, -1 on failure.
 */
int32_t spotti_player_init(struct SpottiCore *core);

void spotti_play(struct SpottiCore *core);

void spotti_pause(struct SpottiCore *core);

void spotti_stop(struct SpottiCore *core);

void spotti_next(struct SpottiCore *core);

void spotti_previous(struct SpottiCore *core);

void spotti_seek(struct SpottiCore *core, uint32_t position_ms);

/**
 * Load and play a single track by Spotify URI.
 * `uri` must be a null-terminated C string like "spotify:track:4uLU6hMCjMI75M1A2tKUQC".
 */
void spotti_load_track(struct SpottiCore *core, const char *uri);

/**
 * Load multiple tracks as a queue. `uris_json` is a JSON array of URI strings.
 * `index` is the starting track index.
 */
void spotti_load_context(struct SpottiCore *core, const char *uris_json, uint32_t index);

/**
 * Set audio quality. 0 = Low (96kbps), 1 = Normal (160kbps), 2 = High (320kbps).
 * Takes effect on next track load.
 */
void spotti_set_bitrate(struct SpottiCore *core, uint32_t level);

/**
 * Set volume (0-100 range, mapped to 0-65535 internally)
 */
void spotti_set_volume(struct SpottiCore *core, uint32_t volume);

/**
 * Set shuffle on/off
 */
void spotti_set_shuffle(struct SpottiCore *core, bool enabled);

/**
 * Set repeat mode: 0 = off, 1 = context, 2 = track
 */
void spotti_set_repeat(struct SpottiCore *core, uint32_t mode);

/**
 * Search Spotify. Results arrive via SearchResults event.
 */
void spotti_search(struct SpottiCore *core, const char *query, uint32_t offset);

/**
 * Fetch user library. Results arrive via LibraryContent event.
 */
void spotti_fetch_library(struct SpottiCore *core);

/**
 * Fetch playlist detail. Results arrive via PlaylistDetail event.
 */
void spotti_fetch_playlist(struct SpottiCore *core, const char *playlist_id);

/**
 * Fetch album detail. Results arrive via AlbumDetail event.
 */
void spotti_fetch_album(struct SpottiCore *core, const char *album_id);

/**
 * Fetch artist detail. Results arrive via ArtistDetail event.
 */
void spotti_fetch_artist(struct SpottiCore *core, const char *artist_id);

/**
 * Fetch available Spotify Connect devices. Results arrive via DeviceList event.
 */
void spotti_fetch_devices(struct SpottiCore *core);

/**
 * Transfer playback to a specific device.
 */
void spotti_transfer_playback(struct SpottiCore *core, const char *device_id, bool start_playing);

/**
 * Get the authenticated username. Returns a C string that must be freed with `spotti_free_string`.
 * Returns null if not authenticated.
 */
char *spotti_get_username(struct SpottiCore *core);

/**
 * Get our librespot device ID. Returns a C string freed with `spotti_free_string`.
 * Returns null if not authenticated.
 */
char *spotti_get_device_id(struct SpottiCore *core);

/**
 * Free a string returned by spotti_get_username.
 */
void spotti_free_string(char *ptr);

/**
 * Query art cache size. Result arrives via CacheInfo event.
 */
void spotti_cache_info(struct SpottiCore *core);

/**
 * Clear all cached art. Emits CacheCleared event when done.
 */
void spotti_clear_cache(struct SpottiCore *core);

/**
 * Start background playback sync. Polls Spotify Web API every 5s.
 * Emits PlaybackSynced events. Safe to call multiple times (cancels previous task).
 */
void spotti_start_playback_sync(struct SpottiCore *core);

/**
 * Stop background playback sync.
 */
void spotti_stop_playback_sync(struct SpottiCore *core);

/**
 * Reconnect after session loss. Uses lightweight `player.set_session()` to
 * hot-swap the session on the existing player — no teardown/rebuild needed.
 * Falls back to full reinit if the engine command channel is dead.
 * Returns 0 on success, -1 on failure.
 */
int32_t spotti_reconnect(struct SpottiCore *core);

/**
 * Resume playback on the currently active device via Web API.
 */
void spotti_web_play(struct SpottiCore *core);

/**
 * Pause playback on the currently active device via Web API.
 */
void spotti_web_pause(struct SpottiCore *core);

/**
 * Skip to next track on the currently active device via Web API.
 */
void spotti_web_next(struct SpottiCore *core);

/**
 * Skip to previous track on the currently active device via Web API.
 */
void spotti_web_previous(struct SpottiCore *core);

/**
 * Seek on the currently active device via Web API.
 */
void spotti_web_seek(struct SpottiCore *core, uint32_t position_ms);

/**
 * Fetch recommendations seeded by a single track ID and begin playback.
 * `track_id` is a bare Spotify ID or URI (null-terminated C string).
 * Emits RadioTracksReady on success, Error on failure.
 */
void spotti_play_song_radio(struct SpottiCore *core, const char *track_id);

/**
 * Fetch recommendations seeded by multiple track IDs (JSON array, up to 5) and begin playback.
 * `name` is the playlist/context name shown in the radio queue view.
 * Emits RadioTracksReady on success, Error on failure.
 */
void spotti_play_playlist_radio(struct SpottiCore *core,
                                const char *seed_ids_json,
                                const char *name);

/**
 * Fetch crowd-sourced genre tags for a track from Last.fm.
 * `track_name` and `artist_name` are null-terminated C strings.
 * Emits TrackTagsReady { tags: [...] } asynchronously.
 */
void spotti_fetch_track_tags(struct SpottiCore *core,
                             const char *track_name,
                             const char *artist_name);

/**
 * Start a radio station seeded by a Last.fm genre tag (e.g. "indie rock").
 * `tag` is a null-terminated C string.
 * Emits RadioTracksReady on success, Error on failure.
 */
void spotti_play_tag_radio(struct SpottiCore *core, const char *tag);

/**
 * Save the current track to Liked Songs.
 * `track_id` is a bare Spotify ID or URI.
 * Emits TrackSavedStatus { is_saved: true } on success.
 */
void spotti_save_track(struct SpottiCore *core, const char *track_id);

/**
 * Remove the current track from Liked Songs.
 * Emits TrackSavedStatus { is_saved: false } on success.
 */
void spotti_unsave_track(struct SpottiCore *core, const char *track_id);

/**
 * Check if a track is in the user's Liked Songs.
 * Emits TrackSavedStatus { is_saved: bool }.
 */
void spotti_check_saved(struct SpottiCore *core, const char *track_id);

/**
 * Add a track URI to a playlist.
 * `playlist_id` and `track_uri` are null-terminated C strings (bare ID or full URI).
 * Emits TrackAddedToPlaylist on success.
 */
void spotti_add_to_playlist(struct SpottiCore *core,
                            const char *playlist_id,
                            const char *track_uri);

/**
 * Cache album art. Result arrives via ArtCached event with local file path.
 */
void spotti_cache_art(struct SpottiCore *core, const char *id, const char *url);

#endif  /* SPOTTI_CORE_H */
