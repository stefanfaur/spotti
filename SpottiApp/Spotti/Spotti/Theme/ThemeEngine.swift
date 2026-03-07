import SwiftUI
import AppKit
import Combine

class ThemeEngine: ObservableObject {
    static let shared = ThemeEngine()

    @Published var dominantColor: Color = Color(nsColor: ExtractedColors.default.dominant)
    @Published var accentColor: Color = Color(nsColor: ExtractedColors.default.accent)

    @AppStorage("theme.blurLevel") var blurLevel: BlurLevel = .subtle

    // MARK: - Glass Island Settings
    @AppStorage("theme.glassCornerRadius")    var glassCornerRadius: Double = 16      // 8–24
    @AppStorage("theme.glassSpacing")         var glassSpacing: Double = 8            // 2–16
    @AppStorage("theme.sidebarTintOpacity")   var sidebarTintOpacity: Double = 0.25   // 0–0.5
    @AppStorage("theme.playerBarTintOpacity") var playerBarTintOpacity: Double = 0.20 // 0–0.5
    @AppStorage("theme.mainContentGlass")     var mainContentGlass: Bool = false
    @AppStorage("theme.mainContentTintOpacity") var mainContentTintOpacity: Double = 0.15 // 0–0.5

    // MARK: - Background Gradient Settings
    @AppStorage("theme.gradientIntensity")    var gradientIntensity: Double = 1.0     // 0.5–1.5
    @AppStorage("theme.radialGlowStrength")   var radialGlowStrength: Double = 0.3    // 0–0.6
    @AppStorage("theme.gradientComplexity")   var gradientComplexity: GradientComplexity = .medium
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
            return Color(nsColor: nsColor.adapted(for: NSApp.effectiveAppearance))
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
    private var appearanceObserver: NSKeyValueObservation?

    private init() {
        appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            guard let self else { return }
            self.applyColors(self.currentColors, force: true)
        }
    }

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

    private func applyColors(_ colors: ExtractedColors, force: Bool = false) {
        guard force || colors != currentColors else { return }
        currentColors = colors

        let adapted = colors.accent.adapted(for: NSApp.effectiveAppearance)
        withAnimation(.spring(response: colorTransitionDuration, dampingFraction: 0.85)) {
            dominantColor = Color(nsColor: colors.dominant)
            accentColor = Color(nsColor: adapted)
        }
    }
}
