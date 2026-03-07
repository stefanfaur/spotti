import Combine
import Foundation

struct SpottiTrackInfo: Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let durationMs: UInt32
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album
        case durationMs = "duration_ms"
        case imageUrl = "image_url"
    }
}

enum SpottiPlayerEvent {
    case playing(track: SpottiTrackInfo, positionMs: UInt32)
    case paused(track: SpottiTrackInfo, positionMs: UInt32)
    case stopped
    case trackChanged(track: SpottiTrackInfo)
    case loading(uri: String)
    case endOfTrack
    case error(message: String)
    case positionChanged(positionMs: UInt32)
}

enum PlaybackMode: Equatable {
    case idle
    case local
    case external(deviceId: String)
}

/// Main bridge class -- singleton that owns the Rust core pointer.
class SpottiEngine: ObservableObject {
    static let shared = SpottiEngine()

    @Published var isPlaying = false
    @Published var currentTrack: SpottiTrackInfo?
    @Published var positionMs: UInt32 = 0
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var lastError: String?
    @Published var searchResults: SearchResults?
    @Published var libraryContent: LibraryContent?
    @Published var currentPlaylist: PlaylistDetail?
    @Published var currentAlbum: AlbumDetail?
    @Published var currentArtist: ArtistDetail?
    @Published var volume: UInt32 = 100
    @Published var shuffleEnabled: Bool = false
    @Published var repeatMode: UInt32 = 0
    @Published var availableDevices: [DeviceInfo] = []
    @Published var activeDeviceId: String?
    @Published var miniPlayerVisible = false
    @Published var cacheSize: UInt64 = 0
    @Published var cacheItemCount: UInt32 = 0
    @Published var playbackMode: PlaybackMode = .idle
    @Published var activeDeviceName: String?

    private var corePtr: OpaquePointer?
    private var positionTimer: Timer?
    private var lastNotifiedTrackId: String?
    private(set) var ourDeviceId: String?
    private var pendingUri: String?

    private init() {}

    func initialize(clientId: String) {
        guard corePtr == nil else { return }

        corePtr = clientId.withCString { ptr in
            spotti_core_create(ptr)
        }

        spotti_set_event_callback(corePtr) { jsonPtr in
            guard let jsonPtr = jsonPtr else { return }
            let json = String(cString: jsonPtr)

            DispatchQueue.main.async {
                SpottiEngine.shared.handleEvent(json: json)
            }
        }

        // Try cached credentials automatically
        authenticate()
    }

    func authenticate() {
        guard let core = corePtr else { return }
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = spotti_authenticate(core)

            DispatchQueue.main.async {
                self?.isLoading = false
                if result == 0 {
                    self?.isAuthenticated = true
                    spotti_player_init(core)
                    self?.setBitrate(UInt32(AppSettings.shared.audioQuality))
                    // Fetch our librespot device ID
                    let ptr = spotti_get_device_id(core)
                    if let ptr = ptr {
                        self?.ourDeviceId = String(cString: ptr)
                        spotti_free_string(ptr)
                    }
                    // Start background sync
                    spotti_start_playback_sync(core)
                    NotificationService.shared.requestPermission()
                }
            }
        }
    }

    func play() {
        guard let core = corePtr else { return }
        switch playbackMode {
        case .local, .idle:
            Task { @MainActor in
                isPlaying = true
                startPositionTimer()
            }
            spotti_play(core)
        case .external:
            Task { @MainActor in isPlaying = true }
            spotti_web_play(core)
        }
    }

    func pause() {
        guard let core = corePtr else { return }
        switch playbackMode {
        case .local, .idle:
            Task { @MainActor in
                isPlaying = false
                stopPositionTimer()
            }
            spotti_pause(core)
        case .external(let deviceId):
            Task { @MainActor in isPlaying = false }
            deviceId.withCString { ptr in
                spotti_web_pause(core, ptr)
            }
        }
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func next() {
        guard let core = corePtr else { return }
        switch playbackMode {
        case .local, .idle:
            Task { @MainActor in isLoading = true }
            spotti_next(core)
        case .external:
            spotti_web_next(core)
        }
    }

    func previous() {
        guard let core = corePtr else { return }
        switch playbackMode {
        case .local, .idle:
            Task { @MainActor in isLoading = true }
            spotti_previous(core)
        case .external:
            spotti_web_previous(core)
        }
    }

    func seek(to positionMs: UInt32) {
        guard let core = corePtr else { return }
        switch playbackMode {
        case .local, .idle:
            Task { @MainActor in self.positionMs = positionMs }
            spotti_seek(core, positionMs)
        case .external:
            Task { @MainActor in self.positionMs = positionMs }
            spotti_web_seek(core, positionMs)
        }
    }

    func loadTrack(uri: String) {
        guard let core = corePtr else { return }
        Task { @MainActor in
            isLoading = true
            isPlaying = true
        }
        uri.withCString { ptr in
            spotti_load_track(core, ptr)
        }
    }

    func loadContext(uris: [String], index: UInt32) {
        guard let core = corePtr else { return }
        Task { @MainActor in
            isLoading = true
            isPlaying = true
        }
        if let jsonData = try? JSONEncoder().encode(uris),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            jsonString.withCString { ptr in
                spotti_load_context(core, ptr, index)
            }
        }
    }

    // MARK: - Search, Library, Detail

    func search(query: String, offset: UInt32 = 0) {
        guard let core = corePtr else { return }
        query.withCString { ptr in
            spotti_search(core, ptr, offset)
        }
    }

    func fetchLibrary() {
        guard let core = corePtr else { return }
        spotti_fetch_library(core)
    }

    func fetchPlaylist(id: String) {
        guard let core = corePtr else { return }
        id.withCString { ptr in
            spotti_fetch_playlist(core, ptr)
        }
    }

    func fetchAlbum(id: String) {
        guard let core = corePtr else { return }
        id.withCString { ptr in
            spotti_fetch_album(core, ptr)
        }
    }

    func fetchArtist(id: String) {
        guard let core = corePtr else { return }
        id.withCString { ptr in
            spotti_fetch_artist(core, ptr)
        }
    }

    // MARK: - Devices (Spotify Connect)

    func fetchDevices() {
        guard let core = corePtr else { return }
        spotti_fetch_devices(core)
    }

    func transferPlayback(to deviceId: String, startPlaying: Bool = true) {
        guard let core = corePtr else { return }
        deviceId.withCString { ptr in
            spotti_transfer_playback(core, ptr, startPlaying)
        }
    }

    // MARK: - Account

    var username: String? {
        guard let core = corePtr else { return nil }
        let ptr = spotti_get_username(core)
        guard let ptr else { return nil }
        let name = String(cString: ptr)
        spotti_free_string(ptr)
        return name
    }

    // MARK: - Cache

    func fetchCacheInfo() {
        guard let core = corePtr else { return }
        spotti_cache_info(core)
    }

    func clearCache() {
        guard let core = corePtr else { return }
        spotti_clear_cache(core)
    }

    // MARK: - Bitrate

    func setBitrate(_ level: UInt32) {
        guard let core = corePtr else { return }
        spotti_set_bitrate(core, level)
    }

    // MARK: - Volume, Shuffle, Repeat

    func setVolume(_ volume: UInt32) {
        guard let core = corePtr else { return }
        Task { @MainActor in self.volume = volume }
        spotti_set_volume(core, volume)
    }

    func setShuffle(_ enabled: Bool) {
        guard let core = corePtr else { return }
        Task { @MainActor in shuffleEnabled = enabled }
        spotti_set_shuffle(core, enabled)
    }

    func setRepeat(_ mode: UInt32) {
        guard let core = corePtr else { return }
        Task { @MainActor in repeatMode = mode }
        spotti_set_repeat(core, mode)
    }

    func toggleShuffle() {
        setShuffle(!shuffleEnabled)
    }

    func cycleRepeat() {
        setRepeat((repeatMode + 1) % 3)
    }

    // MARK: - Position Timer

    private func startPositionTimer() {
        stopPositionTimer()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.positionMs += 1000
        }
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    // MARK: - Event Handling

    private func handleEvent(json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = dict["type"] as? String else { return }

        switch eventType {
        case "Playing":
            isPlaying = true
            if let pos = dict["position_ms"] as? UInt32 {
                positionMs = pos
            }
            decodeTrack(from: dict["track"])
            if let track = currentTrack {
                ThemeEngine.shared.updateColors(for: track)
            }
            playbackMode = .local
            isLoading = false
            startPositionTimer()

        case "Paused":
            isPlaying = false
            if let pos = dict["position_ms"] as? UInt32 {
                positionMs = pos
            }
            stopPositionTimer()

        case "Stopped":
            isPlaying = false
            isLoading = false
            currentTrack = nil
            positionMs = 0
            stopPositionTimer()
            ThemeEngine.shared.resetColors()
            playbackMode = .idle
            activeDeviceName = nil

        case "TrackChanged":
            decodeTrack(from: dict["track"])
            if let track = currentTrack {
                ThemeEngine.shared.updateColors(for: track)
                if track.id != lastNotifiedTrackId {
                    lastNotifiedTrackId = track.id
                    NotificationService.shared.showTrackNotification(
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        imageUrl: track.imageUrl
                    )
                }
            }
            isLoading = false

        case "Loading":
            isLoading = true

        case "EndOfTrack":
            isPlaying = false
            stopPositionTimer()

        case "Error":
            isLoading = false
            if let msg = dict["message"] as? String {
                lastError = msg
            }

        case "PositionChanged":
            if let pos = dict["position_ms"] as? UInt32 {
                positionMs = pos
            }

        case "SearchResults":
            if let resultsJson = dict["results_json"] as? String,
               let data = resultsJson.data(using: .utf8) {
                searchResults = try? JSONDecoder().decode(SearchResults.self, from: data)
            }
        case "LibraryContent":
            if let contentJson = dict["content_json"] as? String,
               let data = contentJson.data(using: .utf8) {
                libraryContent = try? JSONDecoder().decode(LibraryContent.self, from: data)
                if let content = libraryContent {
                    SpotlightIndexer.shared.indexPlaylists(content.playlists)
                    SpotlightIndexer.shared.indexTracks(content.savedTracks)
                }
            }
        case "PlaylistDetail":
            if let detailJson = dict["detail_json"] as? String,
               let data = detailJson.data(using: .utf8) {
                currentPlaylist = try? JSONDecoder().decode(PlaylistDetail.self, from: data)
            }
        case "AlbumDetail":
            if let detailJson = dict["detail_json"] as? String,
               let data = detailJson.data(using: .utf8) {
                currentAlbum = try? JSONDecoder().decode(AlbumDetail.self, from: data)
            }
        case "ArtistDetail":
            if let detailJson = dict["detail_json"] as? String,
               let data = detailJson.data(using: .utf8) {
                currentArtist = try? JSONDecoder().decode(ArtistDetail.self, from: data)
            }
        case "VolumeChanged":
            if let v = dict["volume"] as? Int {
                volume = UInt32((Double(v) / 65535.0) * 100.0)
            }
        case "ShuffleChanged":
            if let enabled = dict["enabled"] as? Bool {
                shuffleEnabled = enabled
            }
        case "RepeatChanged":
            if let modeStr = dict["mode"] as? String {
                switch modeStr {
                case "Context": repeatMode = 1
                case "Track": repeatMode = 2
                default: repeatMode = 0
                }
            }
        case "CacheInfo":
            if let size = dict["size_bytes"] as? UInt64 {
                cacheSize = size
            }
            if let count = dict["item_count"] as? Int {
                cacheItemCount = UInt32(count)
            }

        case "CacheCleared":
            cacheSize = 0
            cacheItemCount = 0

        case "ArtCached":
            break

        case "DeviceList":
            if let devicesJson = dict["devices_json"] as? String,
               let data = devicesJson.data(using: .utf8) {
                availableDevices = (try? JSONDecoder().decode([DeviceInfo].self, from: data)) ?? []
                activeDeviceId = availableDevices.first(where: { $0.isActive })?.id
            }
        case "DeviceTransferred":
            if let deviceId = dict["device_id"] as? String {
                activeDeviceId = deviceId
                fetchDevices()
            }

        case "PlaybackSynced":
            let isOurDevice = dict["is_our_device"] as? Bool ?? false
            let isPlaying = dict["is_playing"] as? Bool ?? false

            if isOurDevice {
                // librespot is authoritative for track/position; only sync shuffle/repeat
                if let shuffleVal = dict["shuffle"] as? Bool {
                    shuffleEnabled = shuffleVal
                }
                if let modeStr = dict["repeat"] as? String {
                    switch modeStr {
                    case "Context": repeatMode = 1
                    case "Track":   repeatMode = 2
                    default:        repeatMode = 0
                    }
                }
                playbackMode = .local
                return
            }

            // External device
            if isPlaying, let trackObj = dict["track"] {
                decodeTrack(from: trackObj)
                if let pos = dict["position_ms"] as? UInt32 {
                    positionMs = pos
                }
                self.isPlaying = true
                activeDeviceName = dict["device_name"] as? String
                let deviceId = dict["device_id"] as? String ?? ""
                playbackMode = .external(deviceId: deviceId)
                if let track = currentTrack {
                    ThemeEngine.shared.updateColors(for: track)
                }
            } else if case .external = playbackMode {
                // Was external, nothing playing now — return to idle
                playbackMode = .idle
                currentTrack = nil
                self.isPlaying = false
                activeDeviceName = nil
                stopPositionTimer()
                ThemeEngine.shared.resetColors()
            }

        default:
            break
        }
    }

    private func decodeTrack(from obj: Any?) {
        guard let trackDict = obj,
              let trackData = try? JSONSerialization.data(withJSONObject: trackDict),
              let track = try? JSONDecoder().decode(SpottiTrackInfo.self, from: trackData)
        else { return }
        currentTrack = track
    }

    deinit {
        stopPositionTimer()
        if let core = corePtr {
            spotti_core_destroy(core)
        }
    }
}
