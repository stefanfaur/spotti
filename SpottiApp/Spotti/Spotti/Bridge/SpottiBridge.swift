import Combine
import Foundation

struct SpottiTrackInfo: Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let durationMs: UInt32

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album
        case durationMs = "duration_ms"
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

/// Main bridge class -- singleton that owns the Rust core pointer.
class SpottiEngine: ObservableObject {
    static let shared = SpottiEngine()

    @Published var isPlaying = false
    @Published var currentTrack: SpottiTrackInfo?
    @Published var positionMs: UInt32 = 0
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var lastError: String?

    private var corePtr: OpaquePointer?
    private var positionTimer: Timer?

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
                }
            }
        }
    }

    func play() {
        guard let core = corePtr else { return }
        spotti_play(core)
    }

    func pause() {
        guard let core = corePtr else { return }
        spotti_pause(core)
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func next() {
        guard let core = corePtr else { return }
        spotti_next(core)
    }

    func previous() {
        guard let core = corePtr else { return }
        spotti_previous(core)
    }

    func seek(to positionMs: UInt32) {
        guard let core = corePtr else { return }
        spotti_seek(core, positionMs)
    }

    func loadTrack(uri: String) {
        guard let core = corePtr else { return }
        uri.withCString { ptr in
            spotti_load_track(core, ptr)
        }
    }

    func loadContext(uris: [String], index: UInt32) {
        guard let core = corePtr else { return }
        if let jsonData = try? JSONEncoder().encode(uris),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            jsonString.withCString { ptr in
                spotti_load_context(core, ptr, index)
            }
        }
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
            currentTrack = nil
            positionMs = 0
            stopPositionTimer()

        case "TrackChanged":
            decodeTrack(from: dict["track"])
            isLoading = false

        case "Loading":
            isLoading = true

        case "EndOfTrack":
            isPlaying = false
            stopPositionTimer()

        case "Error":
            if let msg = dict["message"] as? String {
                lastError = msg
            }

        case "PositionChanged":
            if let pos = dict["position_ms"] as? UInt32 {
                positionMs = pos
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
