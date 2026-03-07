import SwiftUI

struct DevicePickerView: View {
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DEVICES")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            if engine.availableDevices.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Looking for devices...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(engine.availableDevices, id: \.identifier) { device in
                    DeviceRow(device: device)
                }
            }
        }
        .frame(width: 260)
        .padding(.bottom, 10)
        .onAppear {
            engine.fetchDevices()
        }
    }
}

private struct DeviceRow: View {
    let device: DeviceInfo
    @EnvironmentObject private var engine: SpottiEngine
    @EnvironmentObject private var theme: ThemeEngine
    @State private var isHovered = false

    private var isActive: Bool {
        device.id == engine.activeDeviceId
    }

    var body: some View {
        Button {
            if let id = device.id, !isActive {
                engine.transferPlayback(to: id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: device.systemImageName)
                    .font(.body)
                    .foregroundStyle(isActive ? theme.effectiveAccentColor : .primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.callout)
                        .fontWeight(isActive ? .semibold : .regular)
                        .foregroundStyle(isActive ? theme.effectiveAccentColor : .primary)
                    Text(device.deviceType)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(theme.effectiveAccentColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isActive)
    }
}
