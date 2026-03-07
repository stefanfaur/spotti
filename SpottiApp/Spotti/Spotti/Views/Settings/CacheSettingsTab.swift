import SwiftUI

struct CacheSettingsTab: View {
    @EnvironmentObject private var engine: SpottiEngine

    var body: some View {
        Form {
            Section("Album Art Cache") {
                HStack {
                    Text("Cached items")
                    Spacer()
                    Text("\(engine.cacheItemCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("Cache size")
                    Spacer()
                    Text(formattedSize(engine.cacheSize))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("Location")
                    Spacer()
                    Text("~/Library/Caches/spotti/art/")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            Section {
                Button("Clear Album Art Cache", role: .destructive) {
                    engine.clearCache()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            engine.fetchCacheInfo()
        }
    }

    private func formattedSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
