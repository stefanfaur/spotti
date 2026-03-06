import Foundation

struct DeviceInfo: Codable, Identifiable {
    let id: String?
    let name: String
    let deviceType: String
    let isActive: Bool
    let volumePercent: UInt32?

    var identifier: String { id ?? name }

    enum CodingKeys: String, CodingKey {
        case id, name
        case deviceType = "device_type"
        case isActive = "is_active"
        case volumePercent = "volume_percent"
    }

    var systemImageName: String {
        switch deviceType {
        case "Computer": return "laptopcomputer"
        case "Smartphone": return "iphone"
        case "Speaker": return "hifispeaker"
        case "Tv": return "tv"
        case "CastVideo", "CastAudio": return "airplayaudio"
        default: return "speaker.wave.2"
        }
    }
}
