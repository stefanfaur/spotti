import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: SpottiEngine

    var body: some View {
        VStack(spacing: 0) {
            if let error = engine.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                    Spacer()
                    Button("Dismiss") { engine.lastError = nil }
                }
                .padding()
                .background(.red.opacity(0.1))
            }

            if !engine.isAuthenticated {
                LoginView()
            } else {
                MainLayout()
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var engine: SpottiEngine

    var body: some View {
        VStack(spacing: 20) {
            Text("Spotti")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Connect your Spotify account to get started")
                .foregroundStyle(.secondary)

            Button("Sign in with Spotify") {
                engine.authenticate()
            }
            .buttonStyle(.borderedProminent)
            .disabled(engine.isLoading)

            if engine.isLoading {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainLayout: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SidebarView()
                    .frame(width: 240)

                Divider()

                MainContentView()
            }

            Divider()

            PlayerBarView()
                .frame(height: 80)
        }
    }
}
