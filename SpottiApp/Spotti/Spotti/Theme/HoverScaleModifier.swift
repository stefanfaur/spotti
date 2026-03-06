import SwiftUI

extension View {
    func hoverScale(_ amount: CGFloat = 1.03) -> some View {
        modifier(HoverScaleModifier(scaleAmount: amount))
    }

    func hoverHighlight(cornerRadius: CGFloat = 6) -> some View {
        modifier(HoverHighlightModifier(cornerRadius: cornerRadius))
    }
}

private struct HoverScaleModifier: ViewModifier {
    let scaleAmount: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleAmount : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

private struct HoverHighlightModifier: ViewModifier {
    let cornerRadius: CGFloat
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.white.opacity(0.06))
                        .glassEffect(
                            .regular,
                            in: .rect(cornerRadius: cornerRadius)
                        )
                }
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
