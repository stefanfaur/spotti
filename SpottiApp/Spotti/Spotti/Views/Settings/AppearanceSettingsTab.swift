import SwiftUI

struct AppearanceSettingsTab: View {
    @EnvironmentObject private var theme: ThemeEngine
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $settings.theme) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.theme) { _, _ in
                    settings.applyThemeMode()
                }
            }

            Section("Window") {
                Picker("Window blur", selection: $theme.blurLevel) {
                    ForEach(BlurLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Glass") {
                Toggle("Adaptive color from album art", isOn: $theme.adaptiveColorEnabled)
            }

            Section("Colors") {
                Picker("Color transition speed", selection: $settings.colorTransitionSpeed) {
                    Text("Instant").tag(0)
                    Text("Fast").tag(1)
                    Text("Normal").tag(2)
                    Text("Slow").tag(3)
                }

                Toggle("Use fixed accent color", isOn: Binding(
                    get: { !settings.fixedAccentHex.isEmpty },
                    set: { enabled in
                        if !enabled {
                            settings.fixedAccentHex = ""
                        } else {
                            settings.fixedAccentHex = "#5E81AC"
                        }
                    }
                ))

                if !settings.fixedAccentHex.isEmpty {
                    ColorPicker("Accent color", selection: Binding(
                        get: {
                            if let nsColor = NSColor(hex: settings.fixedAccentHex) {
                                return Color(nsColor: nsColor)
                            }
                            return .accentColor
                        },
                        set: { newColor in
                            let nsColor = NSColor(newColor)
                            settings.fixedAccentHex = nsColor.hexString
                        }
                    ))
                }
            }

            Section("Layout") {
                Picker("Track list density", selection: $settings.trackListDensity) {
                    Text("Comfortable").tag(0)
                    Text("Compact").tag(1)
                }

                Toggle("Show album art in player bar", isOn: $settings.showPlayerBarArt)
            }
        }
        .formStyle(.grouped)
    }
}
