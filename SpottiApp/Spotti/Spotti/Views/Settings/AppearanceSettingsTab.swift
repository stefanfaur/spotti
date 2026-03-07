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

            Section("Glass — Islands") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Corner radius")
                        Spacer()
                        Text("\(Int(theme.glassCornerRadius))pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.glassCornerRadius, in: 8...24, step: 2)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Island spacing")
                        Spacer()
                        Text("\(Int(theme.glassSpacing))pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.glassSpacing, in: 2...16, step: 2)
                }

                Toggle("Glass on main content panel", isOn: $theme.mainContentGlass)
            }

            Section("Glass — Tinting") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Sidebar tint")
                        Spacer()
                        Text("\(Int(theme.sidebarTintOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.sidebarTintOpacity, in: 0...0.5, step: 0.05)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Player bar tint")
                        Spacer()
                        Text("\(Int(theme.playerBarTintOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.playerBarTintOpacity, in: 0...0.5, step: 0.05)
                }

                Toggle("Adaptive color from album art", isOn: $theme.adaptiveColorEnabled)
            }

            Section("Glass — Background") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Gradient intensity")
                        Spacer()
                        Text(String(format: "%.1f×", theme.gradientIntensity))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.gradientIntensity, in: 0.5...1.5, step: 0.1)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Radial glow")
                        Spacer()
                        Text("\(Int(theme.radialGlowStrength * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.radialGlowStrength, in: 0...0.6, step: 0.05)
                }

                Picker("Gradient complexity", selection: $theme.gradientComplexity) {
                    ForEach(GradientComplexity.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
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
