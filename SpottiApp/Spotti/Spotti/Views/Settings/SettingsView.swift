import SwiftUI
import AppKit

enum BlurLevel: Int, CaseIterable, Hashable {
    case none = 0
    case subtle = 1
    case medium = 2
    case heavy = 3

    var label: String {
        switch self {
        case .none: "None"
        case .subtle: "Subtle"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }

    var material: NSVisualEffectView.Material {
        switch self {
        case .none: .windowBackground
        case .subtle: .hudWindow
        case .medium: .fullScreenUI
        case .heavy: .sheet
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Window blur", selection: $theme.blurLevel) {
                    ForEach(BlurLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading) {
                    HStack {
                        Text("Glass tint opacity")
                        Spacer()
                        Text("\(Int(theme.glassTintOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $theme.glassTintOpacity, in: 0...0.5, step: 0.05)
                }

                Toggle("Adaptive color from album art", isOn: $theme.adaptiveColorEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 240)
    }
}
