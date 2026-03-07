import SwiftUI
import AppKit

enum BlurLevel: Int, CaseIterable, Hashable {
    case none = 0
    case subtle = 1
    case medium = 2
    case heavy = 3

    var label: String {
        switch self {
        case .none: "None"
        case .subtle: "Subtle"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .none: .windowBackground
        case .subtle: .hudWindow
        case .medium: .fullScreenUI
        case .heavy: .sheet
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            PlaybackSettingsTab()
                .tabItem {
                    Label("Playback", systemImage: "play.circle")
                }

            ShortcutsSettingsTab()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            CacheSettingsTab()
                .tabItem {
                    Label("Cache & Data", systemImage: "internaldrive")
                }

            AccountSettingsTab()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
        }
        .frame(width: 520, height: 420)
    }
}
