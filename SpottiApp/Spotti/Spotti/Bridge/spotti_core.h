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
 * Get our librespot device ID. Returns a C string freed with `spotti_free_string`.
 * Returns null if not authenticated.
 */
char *spotti_get_device_id(struct SpottiCore *core);

/**
 * Start background playback sync. Polls Spotify Web API every 5s.
 * Emits PlaybackSynced events. Safe to call multiple times.
 */
void spotti_start_playback_sync(struct SpottiCore *core);

/**
 * Stop background playback sync.
 */
void spotti_stop_playback_sync(struct SpottiCore *core);

/**
 * Resume playback on active device via Web API.
 */
void spotti_web_play(struct SpottiCore *core);

/**
 * Pause playback on active device via Web API.
 * device_id: null-terminated C string (reserved for future use; currently targets active device).
 */
void spotti_web_pause(struct SpottiCore *core, const char *device_id);

/**
 * Skip to next track on active device via Web API.
 */
void spotti_web_next(struct SpottiCore *core);

/**
 * Skip to previous track on active device via Web API.
 */
void spotti_web_previous(struct SpottiCore *core);

/**
 * Seek on active device via Web API. position_ms is position in milliseconds.
 */
void spotti_web_seek(struct SpottiCore *core, uint32_t position_ms);

/**
 * Get the authenticated username. Returns a C string that must be freed with `spotti_free_string`.
 * Returns null if not authenticated.
 */
char *spotti_get_username(struct SpottiCore *core);

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
 * Cache album art. Result arrives via ArtCached event with local file path.
 */
void spotti_cache_art(struct SpottiCore *core, const char *id, const char *url);

#endif  /* SPOTTI_CORE_H */
