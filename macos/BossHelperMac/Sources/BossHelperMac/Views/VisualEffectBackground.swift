import AppKit
import SwiftUI

/// A native NSVisualEffectView wrapper that renders a frosted glass backdrop
/// by blurring whatever is behind the window.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

/// A rounded native liquid-glass surface used for cards floating on the glass canvas.
/// Applied as a modifier so the glass sits *behind* the card content and the
/// text composites on top of the glass as native "glass content".
struct MaterialSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0.8
    var tint: Color = .clear
    var hasShadow: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            // Native macOS 26 liquid glass — the same glass system as the sidebar.
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if tint != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if borderColor != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: borderWidth)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: hasShadow
                    ? Color.black.opacity(colorScheme == .dark ? 0.30 : 0.12)
                    : .clear,
                radius: hasShadow ? 10 : 0,
                x: 0,
                y: hasShadow ? 4 : 0
            )
    }
}
