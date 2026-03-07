import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        VStack(spacing: 0) {
            if let error = engine.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            engine.lastError = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(.red.opacity(0.15), in: .rect(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if engine.isAuthenticated {
                MainLayout()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(VisualEffectBackground(material: theme.blurLevel.material))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: engine.isAuthenticated)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: engine.lastError != nil)
    }
}

struct LoginView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        VStack(spacing: 24) {
            Text("Spotti")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Connect your Spotify account to get started")
                .foregroundStyle(.secondary)

            Button {
                engine.authenticate()
            } label: {
                Label("Sign in with Spotify", systemImage: "music.note")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .disabled(engine.isLoading)
            .scaleEffect(engine.isLoading ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.isLoading)

            if engine.isLoading {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MainLayout: View {
    @EnvironmentObject private var theme: ThemeEngine
    @State private var showNowPlaying = false

    var body: some View {
        ZStack {
            // Multi-layer ambient background — gives glass rich content to refract and reflect
            ZStack {
                LinearGradient(
                    colors: [
                        theme.dominantColor.opacity(0.45),
                        theme.effectiveAccentColor.opacity(0.25),
                        theme.dominantColor.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Secondary radial glow for more depth in the refraction
                RadialGradient(
                    colors: [
                        theme.effectiveAccentColor.opacity(0.3),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    SidebarView()
                        .frame(width: 240)
                        .clipShape(.rect(cornerRadius: 16))
                        .glassEffect(
                            .regular.tint(theme.dominantColor.opacity(0.25)),
                            in: .rect(cornerRadius: 16)
                        )

                    MainContentView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(.rect(cornerRadius: 16))
                }

                PlayerBarView(showNowPlaying: $showNowPlaying)
                    .frame(height: 80)
                    .clipShape(.rect(cornerRadius: 16))
                    .glassEffect(
                        .regular.tint(theme.dominantColor.opacity(0.2)),
                        in: .rect(cornerRadius: 16)
                    )
            }
            .padding(8)

            if showNowPlaying {
                NowPlayingFullView(showNowPlaying: $showNowPlaying)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showNowPlaying)
    }
}
