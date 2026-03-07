import AppKit
import Foundation

extension NSColor {
    /// Returns a copy of the color with brightness adjusted to ensure legibility
    /// against typical dark (≥0.70) or light (≤0.45) backgrounds.
    func adapted(for appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard let srgb = usingColorSpace(.sRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if isDark {
            return NSColor(hue: h, saturation: min(s, 0.85), brightness: max(b, 0.70), alpha: a)
        } else {
            return NSColor(hue: h, saturation: min(s + 0.1, 1.0), brightness: min(b, 0.45), alpha: a)
        }
    }

    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else { return nil }
        self.init(
            red: CGFloat((hexNumber & 0xFF0000) >> 16) / 255,
            green: CGFloat((hexNumber & 0x00FF00) >> 8) / 255,
            blue: CGFloat(hexNumber & 0x0000FF) / 255,
            alpha: 1.0
        )
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
}

struct ExtractedColors: Equatable {
    let dominant: NSColor
    let accent: NSColor

    static let `default` = ExtractedColors(
        dominant: NSColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1),
        accent: NSColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 1)
    )
}

enum ColorExtractor {

    static func extractColors(from url: URL) -> ExtractedColors {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return .default
        }

        return extractColors(from: cgImage)
    }

    static func extractColors(from cgImage: CGImage) -> ExtractedColors {
        let sampleSize = 40
        guard let context = CGContext(
            data: nil,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .default
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        guard let data = context.data else { return .default }

        let pointer = data.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        let pixelCount = sampleSize * sampleSize

        struct HueBucket {
            var totalR: Double = 0
            var totalG: Double = 0
            var totalB: Double = 0
            var count: Int = 0
            var totalSaturation: Double = 0
        }

        var buckets = [HueBucket](repeating: HueBucket(), count: 12)

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = Double(pointer[offset]) / 255.0
            let g = Double(pointer[offset + 1]) / 255.0
            let b = Double(pointer[offset + 2]) / 255.0

            let color = NSColor(red: r, green: g, blue: b, alpha: 1)
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &br, alpha: &a)

            guard s > 0.15, br > 0.15 else { continue }

            let bucketIndex = min(Int(h * 12), 11)
            buckets[bucketIndex].totalR += r
            buckets[bucketIndex].totalG += g
            buckets[bucketIndex].totalB += b
            buckets[bucketIndex].count += 1
            buckets[bucketIndex].totalSaturation += Double(s)
        }

        let scored = buckets.enumerated()
            .filter { $0.element.count > 0 }
            .sorted { lhs, rhs in
                let lScore = Double(lhs.element.count) * (lhs.element.totalSaturation / Double(lhs.element.count))
                let rScore = Double(rhs.element.count) * (rhs.element.totalSaturation / Double(rhs.element.count))
                return lScore > rScore
            }

        guard let first = scored.first else { return .default }
        let dominantBucket = first.element
        let dominantColor = NSColor(
            red: dominantBucket.totalR / Double(dominantBucket.count),
            green: dominantBucket.totalG / Double(dominantBucket.count),
            blue: dominantBucket.totalB / Double(dominantBucket.count),
            alpha: 1
        )

        let dominantIdx = first.offset
        let accentBucket = scored.dropFirst().first { abs($0.offset - dominantIdx) >= 2 || abs($0.offset - dominantIdx) >= 10 }
        let accentColor: NSColor
        if let ab = accentBucket {
            accentColor = NSColor(
                red: ab.element.totalR / Double(ab.element.count),
                green: ab.element.totalG / Double(ab.element.count),
                blue: ab.element.totalB / Double(ab.element.count),
                alpha: 1
            )
        } else {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            dominantColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            accentColor = NSColor(hue: h, saturation: max(s - 0.2, 0.3), brightness: min(b + 0.3, 1.0), alpha: 1)
        }

        return ExtractedColors(dominant: dominantColor, accent: accentColor)
    }
}
