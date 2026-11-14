import AppKit

/// Translucent rounded backdrop for bento's panels: Liquid Glass (`NSGlassEffectView`) on macOS 26+,
/// a blurred `NSVisualEffectView` with a tint layer on older systems.
@MainActor
protocol GlassSurface: NSView {
    var contentView: NSView? { get set }
    var cornerRadius: CGFloat { get set }
    var tintColor: NSColor? { get set }
}

@available(macOS 26, *)
extension NSGlassEffectView: GlassSurface {}

@MainActor
func makeGlass(frame: NSRect = .zero) -> any GlassSurface {
    if #available(macOS 26, *) {
        return NSGlassEffectView(frame: frame)
    }
    return BlurGlassView(frame: frame)
}

/// Pre-Tahoe stand-in for `NSGlassEffectView` with the same three knobs.
@MainActor
private final class BlurGlassView: NSVisualEffectView, GlassSurface {
    private let tint = NSView()

    var contentView: NSView? {
        didSet {
            guard contentView !== oldValue else { return }
            oldValue?.removeFromSuperview()
            guard let contentView else { return }
            contentView.frame = bounds
            contentView.autoresizingMask = [.width, .height]
            addSubview(contentView)
        }
    }

    var cornerRadius: CGFloat = 0 {
        didSet {
            layer?.cornerRadius = cornerRadius
            maskImage = cornerRadius > 0 ? Self.roundedMask(cornerRadius) : nil
        }
    }

    var tintColor: NSColor? {
        didSet { tint.layer?.backgroundColor = tintColor?.cgColor }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        tint.wantsLayer = true
        tint.frame = bounds
        tint.autoresizingMask = [.width, .height]
        addSubview(tint)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Stretchable rounded-rect mask, so the blur itself is clipped and not only the layer.
    private static func roundedMask(_ radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
