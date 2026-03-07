import SwiftUI

struct PlaybackSettingsTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: SpottiEngine

    var body: some View {
        Form {
            Section("Audio Quality") {
                Picker("Streaming quality", selection: $settings.audioQuality) {
                    Text("Low (96 kbps)").tag(0)
                    Text("Normal (160 kbps)").tag(1)
                    Text("High (320 kbps)").tag(2)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.audioQuality) { _, newValue in
                    engine.setBitrate(UInt32(newValue))
                }

                Text("Quality changes take effect on the next track.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Playback") {
                Toggle("Gapless playback", isOn: $settings.gapless)

                Picker("Volume normalization", selection: $settings.normalization) {
                    Text("Off").tag(0)
                    Text("Quiet").tag(1)
                    Text("Normal").tag(2)
                    Text("Loud").tag(3)
                }

                HStack {
                    Text("Crossfade")
                    Spacer()
                    if settings.crossfadeSecs == 0 {
                        Text("Off")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(settings.crossfadeSecs)s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.crossfadeSecs) },
                        set: { settings.crossfadeSecs = Int($0) }
                    ),
                    in: 0...12,
                    step: 1
                )
            }

            Section("Notifications") {
                Toggle("Notify on track change", isOn: $settings.notifyOnTrackChange)
            }
        }
        .formStyle(.grouped)
    }
}
