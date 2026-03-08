import SwiftUI
import AppKit

// MARK: - Transparent Scroll Background

/// Disables the opaque background on the enclosing NSScrollView.
/// Must be applied to content INSIDE a ScrollView (not on the ScrollView itself)
/// so the NSView lands inside the NSScrollView's document view hierarchy.
struct ScrollViewBackgroundClearer: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.setFrameSize(.zero)
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                scrollView.drawsBackground = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-apply on updates in case the scroll view was recreated
        if let scrollView = nsView.enclosingScrollView {
            scrollView.drawsBackground = false
        }
    }
}

// MARK: - Transparent Window

/// Provides a blurred transparent window background using NSVisualEffectView.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active

        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
        }

        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
