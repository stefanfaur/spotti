import SwiftUI

struct MenuBarPlayerView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        VStack(spacing: 0) {
            trackInfoSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 8)

            controlsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 8)

            volumeSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            deviceSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Spotti")
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }

    // MARK: - Track Info

    @ViewBuilder
    private var trackInfoSection: some View {
        HStack(spacing: 12) {
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
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                if let track = engine.currentTrack {
                    Text(track.title)
                        .font(.callout)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Not Playing")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsSection: some View {
        HStack(spacing: 20) {
            Spacer()

            Button { engine.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button { engine.togglePlayPause() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .contentTransition(.symbolEffect(.replace.byLayer.downUp))
            }
            .buttonStyle(.plain)

            Button { engine.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Volume

    @ViewBuilder
    private var volumeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.fill")
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

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
        }
    }

    // MARK: - Device

    @ViewBuilder
    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PLAYING ON")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if let activeDevice = engine.availableDevices.first(where: { $0.isActive }) {
                HStack(spacing: 8) {
                    Image(systemName: activeDevice.systemImageName)
                        .font(.caption)
                        .foregroundStyle(theme.effectiveAccentColor)
                    Text(activeDevice.name)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            } else {
                Text("No active device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { engine.fetchDevices() }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.title == "Spotti" || window.contentView != nil {
                if !window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            HStack {
                Image(systemName: "macwindow")
                Text("Open Spotti")
                Spacer()
            }
            .font(.callout)
        }
        .buttonStyle(.plain)
    }
}
