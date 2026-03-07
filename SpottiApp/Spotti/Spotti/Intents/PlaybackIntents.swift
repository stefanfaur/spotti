import AppIntents

struct PlayIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Music"
    static var description = IntentDescription("Resume playback in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            SpottiEngine.shared.play()
        }
        return .result()
    }
}

struct PauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Music"
    static var description = IntentDescription("Pause playback in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            SpottiEngine.shared.pause()
        }
        return .result()
    }
}

struct TogglePlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Play/Pause"
    static var description = IntentDescription("Toggle between play and pause in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            SpottiEngine.shared.togglePlayPause()
        }
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skip to the next track in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            SpottiEngine.shared.next()
        }
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Go back to the previous track in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            SpottiEngine.shared.previous()
        }
        return .result()
    }
}

struct ToggleShuffleIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Shuffle"
    static var description = IntentDescription("Toggle shuffle mode in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            SpottiEngine.shared.toggleShuffle()
        }
        return .result()
    }
}

struct NowPlayingIntent: AppIntent {
    static var title: LocalizedStringResource = "What's Playing"
    static var description = IntentDescription("Get the currently playing track in Spotti")
    static var openAppWhenRun = false

    func perform() async throws -> some ReturnsValue<String> {
        let result = await MainActor.run {
            if let track = SpottiEngine.shared.currentTrack {
                return "\(track.title) by \(track.artist)"
            }
            return "Nothing is playing"
        }
        return .result(value: result)
    }
}
