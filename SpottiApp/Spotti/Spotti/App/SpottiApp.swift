import SwiftUI

@main
struct SpottiApp: App {
    @StateObject private var engine = SpottiEngine.shared
    @StateObject private var router = Router()
    @StateObject private var theme = ThemeEngine.shared

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
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)
    }
}
