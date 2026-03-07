import AppIntents

struct SpottiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TogglePlayPauseIntent(),
            phrases: [
                "Toggle music in \(.applicationName)",
                "Play or pause \(.applicationName)"
            ],
            shortTitle: "Toggle Play/Pause",
            systemImageName: "playpause"
        )

        AppShortcut(
            intent: NextTrackIntent(),
            phrases: [
                "Skip track in \(.applicationName)",
                "Next song in \(.applicationName)"
            ],
            shortTitle: "Next Track",
            systemImageName: "forward"
        )

        AppShortcut(
            intent: NowPlayingIntent(),
            phrases: [
                "What's playing in \(.applicationName)",
                "Current song in \(.applicationName)"
            ],
            shortTitle: "Now Playing",
            systemImageName: "music.note"
        )
    }
}
