import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @Namespace private var playerBarNamespace

    @Binding var showNowPlaying: Bool

    @State private var isSeekBarHovered = false
    @State private var showDevicePicker = false

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
                    if case .external = engine.playbackMode,
                       let deviceName = engine.activeDeviceName {
                        HStack(spacing: 4) {
                            Image(systemName: "hifispeaker.fill")
                                .font(.system(size: 9))
                            Text(deviceName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Button("Transfer") {
                                showDevicePicker = true
                                engine.fetchDevices()
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.effectiveAccentColor)
                        }
                        .foregroundStyle(.secondary)
                    }
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
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 12) {
                    Button { engine.toggleShuffle() } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 10))
                            .foregroundStyle(engine.shuffleEnabled ? theme.effectiveAccentColor : .primary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)

                    Button { engine.previous() } label: {
                        Image(systemName: "backward.fill")
                            .font(.footnote)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)

                    Button { engine.togglePlayPause() } label: {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.callout)
                            .frame(width: 34, height: 34)
                            .contentTransition(.symbolEffect(.replace.byLayer.downUp))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(theme.effectiveAccentColor)
                    .buttonBorderShape(.circle)
                    .clipShape(Circle())

                    Button { engine.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.footnote)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)

                    Button { engine.cycleRepeat() } label: {
                        Image(systemName: engine.repeatMode == 2 ? "repeat.1" : "repeat")
                            .font(.system(size: 10))
                            .foregroundStyle(engine.repeatMode > 0 ? theme.effectiveAccentColor : .primary)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
            }

            if let track = engine.currentTrack {
                seekBar(duration: track.durationMs)
            }
        }
        .padding(.top, engine.currentTrack != nil ? 6 : 0)
        .padding(.bottom, engine.currentTrack != nil ? 4 : 0)
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
                        .fill(theme.effectiveAccentColor)
                        .frame(width: geo.size.width * progress, height: isSeekBarHovered ? 6 : 4)

                    if isSeekBarHovered {
                        Circle()
                            .fill(theme.effectiveAccentColor)
                            .shadow(color: theme.effectiveAccentColor.opacity(0.5), radius: 4)
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
            .tint(theme.effectiveAccentColor)
            .frame(width: 100)

            Button {
                showDevicePicker.toggle()
                if showDevicePicker {
                    engine.fetchDevices()
                }
            } label: {
                Image(systemName: "hifispeaker.and.appletv")
                    .font(.caption)
                    .foregroundStyle(engine.activeDeviceId != nil ? theme.effectiveAccentColor : .secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .popover(isPresented: $showDevicePicker) {
                DevicePickerView()
                    .environmentObject(engine)
                    .environmentObject(theme)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 200, alignment: .trailing)
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
