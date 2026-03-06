import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @Namespace private var playerBarNamespace

    @Binding var showNowPlaying: Bool

    @State private var isSeekBarHovered = false

    var body: some View {
        HStack(spacing: 16) {
            trackInfoSection
            Spacer()
            playbackControls
            Spacer()
            volumeSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 80)
        .background(.ultraThinMaterial)
    }

    // MARK: - Track Info

    @ViewBuilder
    private var trackInfoSection: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    showNowPlaying = true
                }
            } label: {
                Group {
                    if let track = engine.currentTrack,
                       let urlStr = track.imageUrl,
                       let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.quaternary)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 8))
                .shadow(color: theme.dominantColor.opacity(0.4), radius: 12, y: 3)
            }
            .buttonStyle(.plain)
            .scaleEffect(engine.currentTrack != nil ? 1.0 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.currentTrack?.id)

            if let track = engine.currentTrack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: track.id)
            } else {
                Text("Not Playing")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 250, alignment: .leading)
    }

    // MARK: - Playback Controls

    @ViewBuilder
    private var playbackControls: some View {
        VStack(spacing: 6) {
                HStack(spacing: 16) {
                    Button { engine.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            .font(.caption)
                            .foregroundStyle(engine.shuffleEnabled ? theme.accentColor : .primary)
                            .frame(width: 32, height: 32)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(engine.shuffleEnabled ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: engine.shuffleEnabled)

                    Button { engine.previous() } label: {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)

                    Button { engine.togglePlayPause() } label: {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                            .glassEffect(
                                .regular.tint(theme.accentColor).interactive(),
                                in: .circle
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(engine.isLoading ? 0.9 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: engine.isPlaying)
                    .animation(.spring(response: 0.2, dampingFraction: 0.8), value: engine.isLoading)

                    Button { engine.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)

                    Button { engine.cycleRepeat() } label: {
                        Image(systemName: engine.repeatMode == 2 ? "repeat.1" : "repeat")
                            .font(.caption)
                            .foregroundStyle(engine.repeatMode > 0 ? theme.accentColor : .primary)
                            .frame(width: 32, height: 32)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(engine.repeatMode > 0 ? 1.1 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: engine.repeatMode)
                }

            if let track = engine.currentTrack {
                seekBar(duration: track.durationMs)
            }
        }
        .frame(maxWidth: 400)
    }

    @ViewBuilder
    private func seekBar(duration: UInt32) -> some View {
        HStack(spacing: 8) {
            Text(formatTime(engine.positionMs))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)

            GeometryReader { geo in
                let progress = duration > 0 ? Double(engine.positionMs) / Double(duration) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: isSeekBarHovered ? 6 : 4)

                    Capsule()
                        .fill(theme.accentColor)
                        .frame(width: geo.size.width * progress, height: isSeekBarHovered ? 6 : 4)

                    if isSeekBarHovered {
                        Circle()
                            .fill(theme.accentColor)
                            .shadow(color: theme.accentColor.opacity(0.5), radius: 4)
                            .frame(width: 12, height: 12)
                            .offset(x: geo.size.width * progress - 6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            engine.seek(to: UInt32(fraction * Double(duration)))
                        }
                )
                .onHover { hovering in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        isSeekBarHovered = hovering
                    }
                }
            }
            .frame(height: 12)

            Text(formatTime(duration))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 36, alignment: .leading)
        }
    }

    // MARK: - Volume

    @ViewBuilder
    private var volumeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Slider(
                value: Binding(
                    get: { Double(engine.volume) },
                    set: { engine.setVolume(UInt32($0)) }
                ),
                in: 0...100
            )
            .tint(theme.accentColor)
            .frame(width: 100)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 160, alignment: .trailing)
    }

    private var volumeIcon: String {
        switch engine.volume {
        case 0: "speaker.slash.fill"
        case 1...33: "speaker.wave.1.fill"
        case 34...66: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }

    private func formatTime(_ ms: UInt32) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
