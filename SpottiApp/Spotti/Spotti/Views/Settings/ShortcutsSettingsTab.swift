import SwiftUI

struct ShortcutsSettingsTab: View {
    @StateObject private var shortcuts = KeyboardShortcutManager.shared

    var body: some View {
        Form {
            let categories = Dictionary(grouping: ShortcutAction.allCases, by: \.menuCategory)

            ForEach(["Playback", "Controls", "Navigation"], id: \.self) { category in
                if let actions = categories[category] {
                    Section(category) {
                        ForEach(actions) { action in
                            ShortcutRow(action: action, binding: shortcuts.binding(for: action))
                        }
                    }
                }
            }

            Section {
                Button("Reset to Defaults") {
                    shortcuts.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let action: ShortcutAction
    let binding: ShortcutBinding

    var body: some View {
        HStack {
            Text(action.label)
            Spacer()
            Text(binding.displayString)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .font(.system(.body, design: .monospaced))
        }
    }
}
