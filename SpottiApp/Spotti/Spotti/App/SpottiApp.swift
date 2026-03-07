import SwiftUI
import CoreSpotlight

@main
struct SpottiApp: App {
    @StateObject private var engine = SpottiEngine.shared
    @StateObject private var router = Router()
    @StateObject private var theme = ThemeEngine.shared
    @StateObject private var settings = AppSettings.shared
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
                .environmentObject(settings)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    AppSettings.shared.applyThemeMode()
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }

                    if identifier.hasPrefix("track:") {
                        let trackId = String(identifier.dropFirst("track:".count))
                        engine.loadTrack(uri: "spotify:track:\(trackId)")
                    } else if identifier.hasPrefix("playlist:") {
                        let playlistId = String(identifier.dropFirst("playlist:".count))
                        router.navigate(to: .playlistDetail(id: playlistId))
                    }
                }
        }
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Section {
                    Button("Play / Pause") {
                        engine.togglePlayPause()
                    }
                    .keyboardShortcut(.space, modifiers: [])

                    Button("Next Track") {
                        engine.next()
                    }
                    .keyboardShortcut(.rightArrow, modifiers: .command)

                    Button("Previous Track") {
                        engine.previous()
                    }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                }

                Section {
                    Button("Volume Up") {
                        engine.setVolume(min(engine.volume + 5, 100))
                    }
                    .keyboardShortcut(.upArrow, modifiers: .command)

                    Button("Volume Down") {
                        engine.setVolume(engine.volume > 5 ? engine.volume - 5 : 0)
                    }
                    .keyboardShortcut(.downArrow, modifiers: .command)

                    Button("Toggle Shuffle") {
                        engine.toggleShuffle()
                    }
                    .keyboardShortcut("s", modifiers: .command)

                    Button("Toggle Repeat") {
                        engine.cycleRepeat()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                }

                Section {
                    Button("Search") {
                        router.navigate(to: .search)
                    }
                    .keyboardShortcut("f", modifiers: .command)

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
                .environmentObject(settings)
                .environmentObject(engine)
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
