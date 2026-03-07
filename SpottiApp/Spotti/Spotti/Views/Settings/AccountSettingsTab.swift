import SwiftUI

struct AccountSettingsTab: View {
    @EnvironmentObject private var engine: SpottiEngine

    var body: some View {
        Form {
            Section("Connected Account") {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(engine.username ?? "Not connected")
                            .font(.headline)
                        Text("Spotify Premium")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(engine.isAuthenticated ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(engine.isAuthenticated ? "Connected" : "Disconnected")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Sign Out") {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
    }
}
