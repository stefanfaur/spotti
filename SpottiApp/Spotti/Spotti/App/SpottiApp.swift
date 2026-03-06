import SwiftUI

@main
struct SpottiApp: App {
    @StateObject private var engine = SpottiEngine.shared
    @StateObject private var router = Router()
    @StateObject private var theme = ThemeEngine.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    init() {
        SpottiEngine.shared.initialize(clientId: SpottiConfig.spotifyClientId)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(router)
                .environmentObject(theme)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Mini Player") {
                    if engine.miniPlayerVisible {
                        dismissWindow(id: "mini-player")
                    } else {
                        openWindow(id: "mini-player")
                    }
                    engine.miniPlayerVisible.toggle()
                }
                .keyboardShortcut("m", modifiers: .command)
            }
        }

        Window("Mini Player", id: "mini-player") {
            MiniPlayerView()
                .environmentObject(engine)
                .environmentObject(theme)
                .onDisappear {
                    engine.miniPlayerVisible = false
                }
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
        .windowLevel(.floating)

        Settings {
            SettingsView()
                .environmentObject(theme)
        }

        MenuBarExtra {
            MenuBarPlayerView()
                .environmentObject(engine)
                .environmentObject(theme)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: engine.isPlaying ? "music.note" : "music.note.list")
            }
            .help(
                engine.currentTrack.map { "\($0.title) — \($0.artist)" } ?? "Spotti"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
