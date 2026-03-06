import SwiftUI

@main
struct SpottiApp: App {
    @StateObject private var engine = SpottiEngine.shared

    init() {
        SpottiEngine.shared.initialize(clientId: SpottiConfig.spotifyClientId)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
