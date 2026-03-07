import SwiftUI
import AppKit
import Combine

class ThemeEngine: ObservableObject {
    static let shared = ThemeEngine()

    @Published var dominantColor: Color = Color(nsColor: ExtractedColors.default.dominant)
    @Published var accentColor: Color = Color(nsColor: ExtractedColors.default.accent)

    var glassTint: Color {
        dominantColor.opacity(glassTintOpacity)
    }

    var sidebarTint: Color {
        dominantColor.opacity(0.12)
    }

    var playerBarTint: Color {
        dominantColor.opacity(0.18)
    }

    @AppStorage("theme.glassTintOpacity") var glassTintOpacity: Double = 0.15
    @AppStorage("theme.blurLevel") var blurLevel: BlurLevel = .subtle
    @AppStorage("theme.adaptiveColor") var adaptiveColorEnabled: Bool = true {
        didSet {
            if !adaptiveColorEnabled {
                lastExtractedTrackId = nil
                applyColors(.default)
            }
        }
    }

    var effectiveAccentColor: Color {
        let hex = AppSettings.shared.fixedAccentHex
        if !hex.isEmpty, let nsColor = NSColor(hex: hex) {
            return Color(nsColor: nsColor)
        }
        return accentColor
    }

    var colorTransitionDuration: Double {
        switch AppSettings.shared.colorTransitionSpeed {
        case 0: 0.0
        case 1: 0.3
        case 3: 1.2
        default: 0.6
        }
    }

    private var currentColors: ExtractedColors = .default
    private var lastExtractedTrackId: String?

    private init() {}

    func updateColors(for track: SpottiTrackInfo) {
        guard adaptiveColorEnabled else { return }
        guard track.id != lastExtractedTrackId else { return }
        lastExtractedTrackId = track.id

        guard let urlString = track.imageUrl,
              let url = URL(string: urlString) else {
            applyColors(.default)
            return
        }

        Task.detached(priority: .userInitiated) {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let nsImage = NSImage(data: data),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else {
                await MainActor.run { [weak self] in self?.applyColors(.default) }
                return
            }

            let colors = ColorExtractor.extractColors(from: cgImage)

            await MainActor.run { [weak self] in
                self?.applyColors(colors)
            }
        }
    }

    func resetColors() {
        lastExtractedTrackId = nil
        applyColors(.default)
    }

    private func applyColors(_ colors: ExtractedColors) {
        guard colors != currentColors else { return }
        currentColors = colors

        withAnimation(.spring(response: colorTransitionDuration, dampingFraction: 0.85)) {
            dominantColor = Color(nsColor: colors.dominant)
            accentColor = Color(nsColor: colors.accent)
        }
    }
}
