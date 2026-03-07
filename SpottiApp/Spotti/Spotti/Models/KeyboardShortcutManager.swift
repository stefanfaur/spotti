import SwiftUI
import Combine

enum ShortcutAction: String, CaseIterable, Identifiable {
    case playPause = "playPause"
    case nextTrack = "nextTrack"
    case previousTrack = "previousTrack"
    case volumeUp = "volumeUp"
    case volumeDown = "volumeDown"
    case likeTrack = "likeTrack"
    case toggleShuffle = "toggleShuffle"
    case toggleRepeat = "toggleRepeat"
    case openSearch = "openSearch"
    case showQueue = "showQueue"
    case nowPlayingFull = "nowPlayingFull"
    case toggleMiniPlayer = "toggleMiniPlayer"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playPause: "Play / Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .likeTrack: "Like Current Track"
        case .toggleShuffle: "Toggle Shuffle"
        case .toggleRepeat: "Toggle Repeat"
        case .openSearch: "Open Search"
        case .showQueue: "Show Queue"
        case .nowPlayingFull: "Now Playing Full View"
        case .toggleMiniPlayer: "Toggle Mini Player"
        }
    }

    var menuCategory: String {
        switch self {
        case .playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown:
            "Playback"
        case .likeTrack, .toggleShuffle, .toggleRepeat:
            "Controls"
        case .openSearch, .showQueue, .nowPlayingFull, .toggleMiniPlayer:
            "Navigation"
        }
    }
}

struct ShortcutBinding: Codable, Equatable {
    var key: String          // e.g. " " for space, "f" for F
    var modifiers: UInt      // EventModifiers raw value
}

extension ShortcutBinding {
    var keyEquivalent: KeyEquivalent {
        if key == " " { return .space }
        if key == "\u{1B}" { return .escape }
        if key == "\r" { return .return }
        return KeyEquivalent(Character(key))
    }

    var eventModifiers: EventModifiers {
        EventModifiers(rawValue: Int(modifiers))
    }

    var displayString: String {
        var parts: [String] = []
        let mods = EventModifiers(rawValue: Int(modifiers))
        if mods.contains(.control) { parts.append("\u{2303}") }
        if mods.contains(.option) { parts.append("\u{2325}") }
        if mods.contains(.shift) { parts.append("\u{21E7}") }
        if mods.contains(.command) { parts.append("\u{2318}") }

        // Display key nicely
        switch key {
        case " ": parts.append("Space")
        case String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)): parts.append("\u{2192}")
        case String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)): parts.append("\u{2190}")
        case String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)): parts.append("\u{2191}")
        case String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)): parts.append("\u{2193}")
        default: parts.append(key.uppercased())
        }
        return parts.joined()
    }
}

class KeyboardShortcutManager: ObservableObject {
    static let shared = KeyboardShortcutManager()

    @Published var bindings: [String: ShortcutBinding] = [:]

    private let storageKey = "keyboard.bindings"

    private init() {
        loadBindings()
    }

    static let defaults: [String: ShortcutBinding] = [
        ShortcutAction.playPause.rawValue: ShortcutBinding(key: " ", modifiers: 0),
        ShortcutAction.nextTrack.rawValue: ShortcutBinding(key: String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)), modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.previousTrack.rawValue: ShortcutBinding(key: String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)), modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.volumeUp.rawValue: ShortcutBinding(key: String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)), modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.volumeDown.rawValue: ShortcutBinding(key: String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)), modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.likeTrack.rawValue: ShortcutBinding(key: "l", modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.toggleShuffle.rawValue: ShortcutBinding(key: "s", modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.toggleRepeat.rawValue: ShortcutBinding(key: "r", modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.openSearch.rawValue: ShortcutBinding(key: "f", modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.showQueue.rawValue: ShortcutBinding(key: "q", modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.nowPlayingFull.rawValue: ShortcutBinding(key: "n", modifiers: UInt(EventModifiers.command.rawValue)),
        ShortcutAction.toggleMiniPlayer.rawValue: ShortcutBinding(key: "m", modifiers: UInt(EventModifiers.command.rawValue)),
    ]

    func binding(for action: ShortcutAction) -> ShortcutBinding {
        bindings[action.rawValue] ?? Self.defaults[action.rawValue]!
    }

    func setBinding(_ binding: ShortcutBinding, for action: ShortcutAction) {
        bindings[action.rawValue] = binding
        saveBindings()
    }

    func resetToDefaults() {
        bindings = Self.defaults
        saveBindings()
    }

    private func loadBindings() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ShortcutBinding].self, from: data) else {
            bindings = Self.defaults
            return
        }
        // Merge with defaults so new actions get default bindings
        var merged = Self.defaults
        for (key, value) in decoded {
            merged[key] = value
        }
        bindings = merged
    }

    private func saveBindings() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
