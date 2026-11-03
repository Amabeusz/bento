import AppKit
import HyprCore

private extension RGBA {
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
}

private struct BarStyle: Equatable {
    var height: Double
    var fontSize: Double
    var fontName: String
    var padding: Double
    var rounding: Double
    var background: RGBA
    var active: RGBA
    var otherMonitor: RGBA
    var text: RGBA
    var textActive: RGBA
    var textEmpty: RGBA
    var errorText: RGBA

    init(_ config: Config) {
        height = config.barHeight
        fontSize = config.barFontSize
        fontName = config.barFont
        padding = config.barPadding ?? config.barHeight / 2
        rounding = config.barRounding ?? config.barHeight / 2
        background = config.barBackground
        active = config.barActive
        otherMonitor = config.barOtherMonitor
        text = config.barText
        textActive = config.barTextActive
        textEmpty = config.barTextEmpty
        errorText = config.barError
    }

    var font: NSFont {
        let system = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        return fontName == "system" ? system : NSFont(name: fontName, size: fontSize) ?? system
    }

    var iconSize: Double { max(height - 12, 8) }

    func label(_ number: Int, color: RGBA) -> NSAttributedString {
        NSAttributedString(string: String(number), attributes: [.font: font, .foregroundColor: color.nsColor])
    }

    func width(of badge: WorkspaceBadge) -> Double {
        guard !badge.icons.isEmpty else { return height }
        let icons = Double(badge.icons.count) * (iconSize + 2) - 2
        return height / 3 * 2 + label(badge.number, color: text).size().width + 5 + icons
    }
}

@MainActor
private final class WorkspaceStrip: NSView {
    var badges: [WorkspaceBadge] = [] { didSet { needsDisplay = true } }
    var style = BarStyle(Config()) { didSet { needsDisplay = true } }
    var error: String? {
        didSet {
            toolTip = error
            needsDisplay = true
        }
    }
    var onSelect: (Int) -> Void = { _ in }
    var icon: (WindowID) -> NSImage? = { _ in nil }

    private var cells: [NSRect] {
        var x = style.padding
        return badges.map { badge in
            defer { x += style.width(of: badge) }
            return NSRect(x: x, y: 0, width: style.width(of: badge), height: style.height)
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x
        guard let index = cells.firstIndex(where: { $0.minX <= x && x < $0.maxX }) else { return }
        onSelect(badges[index].number)
    }

    override func draw(_ dirtyRect: NSRect) {
        let cell = style.height
        let rects = cells
        for (badge, rect) in zip(badges, rects) {
            let pill = rect.insetBy(dx: 2, dy: 3)
            if badge.isHere {
                style.active.nsColor.setFill()
                NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            } else if badge.isOnOtherMonitor {
                let outline = pill.insetBy(dx: 0.75, dy: 0.75)
                let path = NSBezierPath(roundedRect: outline, xRadius: outline.height / 2, yRadius: outline.height / 2)
                path.lineWidth = 1.5
                style.otherMonitor.nsColor.setStroke()
                path.stroke()
            }
            let text = style.label(
                badge.number, color: badge.isHere ? style.textActive : badge.isEmpty ? style.textEmpty : style.text)
            let size = text.size()
            guard !badge.icons.isEmpty else {
                text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
                continue
            }
            var x = rect.minX + cell / 3
            text.draw(at: NSPoint(x: x, y: rect.midY - size.height / 2))
            x += size.width + 5
            for id in badge.icons {
                icon(id)?.draw(in: NSRect(
                    x: x, y: rect.midY - style.iconSize / 2, width: style.iconSize, height: style.iconSize))
                x += style.iconSize + 2
            }
        }
        if error != nil {
            let rect = NSRect(x: rects.last.map { Double($0.maxX) } ?? style.padding, y: 0, width: cell, height: cell)
            let text = NSAttributedString(string: "!", attributes: [.font: style.font, .foregroundColor: style.errorText.nsColor])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
        }
    }
}

@MainActor
private final class BarPanel {
    private let panel: NSPanel
    private let glass = NSGlassEffectView()
    private let strip = WorkspaceStrip()
    private var frame: NSRect = .zero

    init(onSelect: @escaping (Int) -> Void, icon: @escaping (WindowID) -> NSImage?) {
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        strip.onSelect = onSelect
        strip.icon = icon
        glass.contentView = strip
        panel.contentView = glass
    }

    func configure(frame: NSRect, badges: [WorkspaceBadge], style: BarStyle, error: String?) {
        if frame != self.frame {
            self.frame = frame
            panel.setFrame(frame, display: true)
        }
        if glass.cornerRadius != style.rounding { glass.cornerRadius = style.rounding }
        let tint = style.background.a > 0 ? style.background.nsColor : nil
        if glass.tintColor != tint { glass.tintColor = tint }
        if strip.style != style { strip.style = style }
        if strip.badges != badges { strip.badges = badges }
        if strip.error != error { strip.error = error }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}

@MainActor
final class BarManager {
    private var panels: [MonitorID: BarPanel] = [:]
    private let onSelect: (Int) -> Void
    private let icon: (WindowID) -> NSImage?

    init(onSelect: @escaping (Int) -> Void, icon: @escaping (WindowID) -> NSImage?) {
        self.onSelect = onSelect
        self.icon = icon
    }

    func update(_ s: LayoutSnapshot, monitors: [MonitorInfo], config: Config, error: String?) {
        guard config.barEnabled else {
            removeAll()
            return
        }
        let style = BarStyle(config)
        let height = config.barHeight
        var live: Set<MonitorID> = []
        for monitor in monitors {
            guard let badges = s.bars[monitor.id] else { continue }
            let width = style.padding * 2 + badges.map(style.width(of:)).reduce(0, +) + (error == nil ? 0 : height)
            guard let frame = appKitFrame(Rect(
                      x: monitor.frame.x + (monitor.frame.w - width) / 2, y: monitor.usable.y + config.barMarginTop,
                      w: width, h: height))
            else { continue }
            live.insert(monitor.id)
            let panel = panels[monitor.id] ?? BarPanel(onSelect: onSelect, icon: icon)
            panels[monitor.id] = panel
            panel.configure(frame: frame, badges: badges, style: style, error: error)
        }
        for id in panels.keys where !live.contains(id) {
            panels.removeValue(forKey: id)?.close()
        }
    }

    func removeAll() {
        panels.values.forEach { $0.close() }
        panels = [:]
    }
}
