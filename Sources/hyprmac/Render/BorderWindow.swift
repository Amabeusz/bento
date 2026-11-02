import AppKit
import HyprCore
import QuartzCore

@MainActor
final class BorderWindow {
    private let window: NSWindow
    private let gradientLayer = CAGradientLayer()
    private let maskLayer = CAShapeLayer()
    private var currentColors: [CGColor] = []

    init() {
        window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .normal
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = NSView()
        view.wantsLayer = true
        view.layer?.addSublayer(gradientLayer)
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = CGColor(gray: 0, alpha: 1)
        gradientLayer.mask = maskLayer
        window.contentView = view
    }

    func configure(
        frame: NSRect, borderSize: Double, rounding: Double, angleDegrees: Double,
        colors: [CGColor], fade: (duration: Double, timing: CAMediaTimingFunction)?
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.setFrame(frame, display: false)
        let bounds = CGRect(origin: .zero, size: frame.size)
        gradientLayer.frame = bounds
        maskLayer.frame = bounds
        maskLayer.path = ringPath(bounds: bounds, borderSize: borderSize, rounding: rounding)
        let (start, end) = Self.gradientPoints(angleDegrees: angleDegrees, size: bounds.size)
        gradientLayer.startPoint = start
        gradientLayer.endPoint = end
        if colors != currentColors {
            let from = gradientLayer.presentation()?.colors ?? currentColors
            gradientLayer.colors = colors
            gradientLayer.removeAnimation(forKey: "colors")
            if let fade, !currentColors.isEmpty {
                let animation = CABasicAnimation(keyPath: "colors")
                animation.fromValue = from
                animation.toValue = colors
                animation.duration = fade.duration
                animation.timingFunction = fade.timing
                gradientLayer.add(animation, forKey: "colors")
            }
            currentColors = colors
        }
        CATransaction.commit()
    }

    func place(above windowID: WindowID) {
        window.order(.above, relativeTo: Int(windowID))
    }

    func hide() {
        window.orderOut(nil)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }

    private func ringPath(bounds: CGRect, borderSize: Double, rounding: Double) -> CGPath {
        let inner = bounds.insetBy(dx: borderSize, dy: borderSize)
        let path = CGMutablePath()
        for (rect, radius) in [(bounds, rounding + borderSize), (inner, rounding)] where rect.width > 0 && rect.height > 0 {
            let r = min(radius, rect.width / 2, rect.height / 2)
            path.addRoundedRect(in: rect, cornerWidth: r, cornerHeight: r)
        }
        return path
    }

    static func gradientPoints(angleDegrees: Double, size: CGSize) -> (start: CGPoint, end: CGPoint) {
        let radians = angleDegrees * .pi / 180
        var ax = sin(radians) * size.width
        var ay = cos(radians) * size.height
        let length = hypot(ax, ay)
        guard size.width > 0, size.height > 0, length > 0 else { return (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5)) }
        ax /= length
        ay /= length
        let half = (abs(ax) + abs(ay)) / 2
        return (CGPoint(x: 0.5 - half * ax, y: 0.5 - half * ay), CGPoint(x: 0.5 + half * ax, y: 0.5 + half * ay))
    }
}

@MainActor
final class BorderManager {
    private var windows: [WindowID: BorderWindow] = [:]
    private var snapshot: LayoutSnapshot?
    private var config = Config()
    private var hidden = false

    func update(_ s: LayoutSnapshot, config: Config) {
        snapshot = s
        self.config = config
        var live: Set<WindowID> = []
        for (id, placement) in s.placements {
            switch placement {
            case .tiled(let r), .floating(let r):
                live.insert(id)
                show(id, frame: r, isFocused: id == s.focused)
            case .parked:
                break
            }
        }
        for id in windows.keys where !live.contains(id) {
            windows.removeValue(forKey: id)?.close()
        }
    }

    func updateFrame(_ id: WindowID, _ frame: Rect) {
        show(id, frame: frame, isFocused: snapshot?.focused == id)
    }

    func hideAll() {
        hidden = true
        windows.values.forEach { $0.hide() }
    }

    func showAll() {
        hidden = false
        guard let snapshot else { return }
        update(snapshot, config: config)
    }

    func removeAll() {
        windows.values.forEach { $0.close() }
        windows = [:]
        snapshot = nil
        hidden = false
    }

    private func show(_ id: WindowID, frame: Rect, isFocused: Bool) {
        guard let appKit = appKitFrame(frame.inset(by: -config.borderSize)) else { return }
        let border = windows[id] ?? BorderWindow()
        windows[id] = border
        border.configure(
            frame: appKit, borderSize: config.borderSize, rounding: config.rounding,
            angleDegrees: (isFocused ? config.activeBorder : config.inactiveBorder).angleDegrees,
            colors: colors(isFocused: isFocused), fade: fade())
        if !hidden { border.place(above: id) }
    }

    private func colors(isFocused: Bool) -> [CGColor] {
        let count = max(2, config.activeBorder.colors.count, config.inactiveBorder.colors.count)
        return Self.resample((isFocused ? config.activeBorder : config.inactiveBorder).colors, to: count)
    }

    private func fade() -> (duration: Double, timing: CAMediaTimingFunction)? {
        guard config.animationsEnabled, let spec = config.animations["border"], spec.enabled else { return nil }
        let curve = config.beziers[spec.curve] ?? CubicBezierSpec(x1: 0, y1: 0, x2: 1, y2: 1)
        let timing = CAMediaTimingFunction(controlPoints: Float(curve.x1), Float(curve.y1), Float(curve.x2), Float(curve.y2))
        return (spec.duration, timing)
    }

    static func resample(_ colors: [RGBA], to count: Int) -> [CGColor] {
        guard !colors.isEmpty else { return [CGColor](repeating: CGColor(gray: 0, alpha: 0), count: count) }
        return (0..<count).map { i in
            let position = Double(i) / Double(count - 1) * Double(colors.count - 1)
            let low = Int(position)
            let high = min(low + 1, colors.count - 1)
            let f = position - Double(low)
            let a = colors[low]
            let b = colors[high]
            return CGColor(
                srgbRed: a.r + (b.r - a.r) * f, green: a.g + (b.g - a.g) * f,
                blue: a.b + (b.b - a.b) * f, alpha: a.a + (b.a - a.a) * f)
        }
    }
}
