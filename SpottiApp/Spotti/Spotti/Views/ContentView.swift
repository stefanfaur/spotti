import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        VStack(spacing: 0) {
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

struct ErrorToastView: View {
    let message: String
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red.opacity(0.8))
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(
            .regular.tint(.red.opacity(0.1)),
            in: .capsule
        )
    }
}

struct MainLayout: View {
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var engine: SpottiEngine
    @State private var showNowPlaying = false
    @State private var visibleError: String?

    var body: some View {
        ZStack {
            // Multi-layer ambient background — gives glass rich content to refract and reflect
            ZStack {
                LinearGradient(
                    colors: [
                        theme.dominantColor.opacity(0.45 * theme.gradientIntensity),
                        theme.effectiveAccentColor.opacity(0.25 * theme.gradientIntensity),
                        theme.dominantColor.opacity(0.15 * theme.gradientIntensity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Secondary radial glow for more depth in the refraction
                RadialGradient(
                    colors: [
                        theme.effectiveAccentColor.opacity(theme.radialGlowStrength),
                        .clear
                    ],
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 400
                )

                if theme.gradientComplexity == .rich {
                    RadialGradient(
                        colors: [
                            theme.effectiveAccentColor.opacity(0.2 * theme.gradientIntensity),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 30,
                        endRadius: 300
                    )
                }
            }
            .ignoresSafeArea()

            GlassEffectContainer(spacing: theme.glassSpacing) {
                VStack(spacing: theme.glassSpacing) {
                    HStack(spacing: theme.glassSpacing) {
                        SidebarView()
                            .frame(width: 240)
                            .clipShape(.rect(cornerRadius: theme.glassCornerRadius))
                            .glassEffect(
                                .regular.tint(theme.dominantColor.opacity(theme.sidebarTintOpacity)),
                                in: .rect(cornerRadius: theme.glassCornerRadius)
                            )

                        Group {
                            if theme.mainContentGlass {
                                MainContentView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(.rect(cornerRadius: theme.glassCornerRadius))
                                    .glassEffect(
                                        .regular.tint(theme.dominantColor.opacity(theme.sidebarTintOpacity)),
                                        in: .rect(cornerRadius: theme.glassCornerRadius)
                                    )
                            } else {
                                MainContentView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(.rect(cornerRadius: theme.glassCornerRadius))
                            }
                        }
                    }

                    PlayerBarView(showNowPlaying: $showNowPlaying)
                        .frame(height: 80)
                        .clipShape(.rect(cornerRadius: theme.glassCornerRadius))
                        .glassEffect(
                            .regular.tint(theme.dominantColor.opacity(theme.playerBarTintOpacity)),
                            in: .rect(cornerRadius: theme.glassCornerRadius)
                        )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            if showNowPlaying {
                NowPlayingFullView(showNowPlaying: $showNowPlaying)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if let error = visibleError {
                VStack {
                    Spacer()
                    ErrorToastView(message: error)
                        .padding(.bottom, 96)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.85))
                        )
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showNowPlaying)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: visibleError != nil)
        .onChange(of: engine.lastError) { _, newError in
            if let error = newError {
                withAnimation {
                    visibleError = error
                }
                engine.lastError = nil
            }
        }
        .task(id: visibleError) {
            guard visibleError != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                visibleError = nil
            }
        }
    }
}
