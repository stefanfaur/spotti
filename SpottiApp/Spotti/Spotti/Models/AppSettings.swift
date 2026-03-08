import SwiftUI
import Combine

/// Central settings store. All values persist via @AppStorage.
/// Playback settings that affect Rust core are forwarded via SpottiEngine on change.
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - Playback

    /// Audio quality: 0 = Low (96kbps), 1 = Normal (160kbps), 2 = High (320kbps)
    @AppStorage("playback.audioQuality") var audioQuality: Int = 2

    /// Volume normalization: 0 = Off, 1 = Quiet, 2 = Normal, 3 = Loud
    @AppStorage("playback.normalization") var normalization: Int = 0

    /// Crossfade duration in seconds (0 = off)
    @AppStorage("playback.crossfadeSecs") var crossfadeSecs: Int = 0

    /// Gapless playback
    @AppStorage("playback.gapless") var gapless: Bool = true

    // MARK: - Appearance

    /// Theme: 0 = System, 1 = Light, 2 = Dark
    @AppStorage("appearance.theme") var theme: Int = 0

    /// Fixed accent color (hex string, empty = dynamic)
    @AppStorage("appearance.fixedAccentHex") var fixedAccentHex: String = ""

    /// Color transition speed: 0 = Instant, 1 = Fast (0.3s), 2 = Normal (0.6s), 3 = Slow (1.2s)
    @AppStorage("appearance.colorTransitionSpeed") var colorTransitionSpeed: Int = 2

    /// Track list density: 0 = Comfortable, 1 = Compact
    @AppStorage("appearance.trackListDensity") var trackListDensity: Int = 0

    /// Show album art in player bar
    @AppStorage("appearance.showPlayerBarArt") var showPlayerBarArt: Bool = true

    // MARK: - Notifications

    @AppStorage("notifications.trackChange") var notifyOnTrackChange: Bool = true

    // MARK: - Playlist Actions
    @AppStorage("actions.lastUsedPlaylistId") var lastUsedPlaylistId: String = ""

    // MARK: - Theme Mode

    func applyThemeMode() {
        switch theme {
        case 1:
            NSApp.appearance = NSAppearance(named: .aqua)
        case 2:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // follows system
        }
    }

    private init() {}
}
