import SwiftUI

struct NowPlayingFullView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @Binding var showNowPlaying: Bool

    @State private var isSeekBarHovered = false

    private func dismiss() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            showNowPlaying = false
        }
    }

    var body: some View {
        ZStack {
            // Full-window tap target to dismiss
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            backgroundLayer
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close button row — fixed height so it never collapses
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .contentShape(Circle())
                            .glassEffect(.regular, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 24)
                }
                .frame(height: 60)
                .padding(.top, 8)

                Spacer(minLength: 8)

                albumArtView

                Spacer()
                    .frame(height: 32)

                trackInfoView

                Spacer()
                    .frame(height: 24)

                seekBarView

                Spacer()
                    .frame(height: 20)

                controlsView

                Spacer()
                    .frame(height: 16)

                secondaryControls

                Spacer(minLength: 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onExitCommand { dismiss() }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            if let track = engine.currentTrack,
               let urlStr = track.imageUrl,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 60)
                        .scaleEffect(1.2)
                } placeholder: {
                    Color.black
                }
            } else {
                Color.black
            }

            theme.dominantColor.opacity(0.4)
                .blendMode(.overlay)

            Color.black.opacity(0.25)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: engine.currentTrack?.id)
    }

    // MARK: - Album Art

    @ViewBuilder
    private var albumArtView: some View {
        Group {
            if let track = engine.currentTrack,
               let urlStr = track.imageUrl,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.quaternary)
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
            }
        }
        .frame(width: 340, height: 340)
        .clipShape(.rect(cornerRadius: 16))
        .glassEffect(
            .regular.tint(theme.dominantColor),
            in: .rect(cornerRadius: 16)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
        .shadow(color: theme.dominantColor.opacity(0.4), radius: 25, y: 5)
        .scaleEffect(engine.isPlaying ? 1.0 : 0.95)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: engine.isPlaying)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: engine.currentTrack?.id)
    }

    // MARK: - Track Info

    @ViewBuilder
    private var trackInfoView: some View {
        VStack(spacing: 6) {
            if let track = engine.currentTrack {
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .id(track.id + "_title")

                Text(track.artist)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .id(track.id + "_artist")

                if !engine.currentTrackTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(engine.currentTrackTags, id: \.self) { tag in
                                Button(tag) {
                                    engine.playTagRadio(tag: tag)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundStyle(.white.opacity(0.9))
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(.horizontal, 40)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: engine.currentTrack?.id)
    }

    // MARK: - Seek Bar

    @ViewBuilder
    private var seekBarView: some View {
        if let track = engine.currentTrack {
            VStack(spacing: 4) {
                GeometryReader { geo in
                    let progress = track.durationMs > 0
                        ? Double(engine.positionMs) / Double(track.durationMs) : 0

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: isSeekBarHovered ? 6 : 4)

                        Capsule()
                            .fill(theme.effectiveAccentColor)
                            .frame(width: geo.size.width * progress, height: isSeekBarHovered ? 6 : 4)

                        if isSeekBarHovered {
                            Circle()
                                .fill(.white)
                                .shadow(color: theme.effectiveAccentColor.opacity(0.6), radius: 4)
                                .frame(width: 14, height: 14)
                                .offset(x: geo.size.width * progress - 7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                engine.seek(to: UInt32(fraction * Double(track.durationMs)))
                            }
                    )
                    .onHover { hovering in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isSeekBarHovered = hovering
                        }
                    }
                }
                .frame(height: 14)

                HStack {
                    Text(formatTime(engine.positionMs))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                    Spacer()
                    Text(formatTime(track.durationMs))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsView: some View {
        GlassEffectContainer(spacing: theme.glassSpacing) {
            HStack(spacing: 28) {
                Button { engine.toggleShuffle() } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundStyle(engine.shuffleEnabled ? theme.effectiveAccentColor : .white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)

                Button { engine.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)

                Button { engine.togglePlayPause() } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .contentShape(Circle())
                        .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                        .glassEffect(
                            .regular.tint(theme.effectiveAccentColor),
                            in: .circle
                        )
                }
                .buttonStyle(.plain)

                Button { engine.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)

                Button { engine.cycleRepeat() } label: {
                    Image(systemName: engine.repeatMode == 2 ? "repeat.1" : "repeat")
                        .font(.title3)
                        .foregroundStyle(engine.repeatMode > 0 ? theme.effectiveAccentColor : .white.opacity(0.7))
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Secondary Controls

    @ViewBuilder
    private var secondaryControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Slider(
                value: Binding(
                    get: { Double(engine.volume) },
                    set: { engine.setVolume(UInt32($0)) }
                ),
                in: 0...100
            )
            .tint(theme.effectiveAccentColor)
            .frame(width: 120)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 40)
    }

    private func formatTime(_ ms: UInt32) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
