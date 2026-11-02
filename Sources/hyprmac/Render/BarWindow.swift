import AppKit
import HyprCore

private func color(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

private struct BarStyle: Equatable {
    var height: Double
    var fontSize: Double
    var fontName: String

    init(_ config: Config) {
        height = config.barHeight
        fontSize = config.barFontSize
        fontName = config.barFont
    }

    var font: NSFont {
        let system = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        return fontName == "system" ? system : NSFont(name: fontName, size: fontSize) ?? system
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

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let x = convert(event.locationInWindow, from: nil).x - style.height / 2
        let index = Int((x / style.height).rounded(.down))
        guard badges.indices.contains(index) else { return }
        onSelect(badges[index].number)
    }

    override func draw(_ dirtyRect: NSRect) {
        let cell = style.height
        for (index, badge) in badges.enumerated() {
            let rect = NSRect(x: cell / 2 + cell * Double(index), y: 0, width: cell, height: cell)
            let pill = rect.insetBy(dx: 2, dy: 3)
            if badge.isHere {
                color(0xf5c2e7).setFill()
                NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
            } else if badge.isOnOtherMonitor {
                let outline = pill.insetBy(dx: 0.75, dy: 0.75)
                let path = NSBezierPath(roundedRect: outline, xRadius: outline.height / 2, yRadius: outline.height / 2)
                path.lineWidth = 1.5
                color(0xcba6f7).setStroke()
                path.stroke()
            }
            let text = NSAttributedString(
                string: String(badge.number),
                attributes: [
                    .font: style.font,
                    .foregroundColor: badge.isHere ? color(0x1e1e2e) : badge.isEmpty ? color(0x6c7086) : color(0xcdd6f4),
                ])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
        }
        if error != nil {
            let rect = NSRect(x: cell / 2 + cell * Double(badges.count), y: 0, width: cell, height: cell)
            let text = NSAttributedString(string: "!", attributes: [.font: style.font, .foregroundColor: color(0xf38ba8)])
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

    init(onSelect: @escaping (Int) -> Void) {
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
        glass.contentView = strip
        panel.contentView = glass
    }

    func configure(frame: NSRect, badges: [WorkspaceBadge], style: BarStyle, error: String?) {
        if frame != self.frame {
            self.frame = frame
            panel.setFrame(frame, display: true)
        }
        if glass.cornerRadius != style.height / 2 { glass.cornerRadius = style.height / 2 }
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

    init(onSelect: @escaping (Int) -> Void) {
        self.onSelect = onSelect
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
            let width = height * Double(badges.count + (error == nil ? 1 : 2))
            guard let frame = appKitFrame(Rect(
                      x: monitor.frame.x + (monitor.frame.w - width) / 2, y: monitor.usable.y + 4, w: width, h: height))
            else { continue }
            live.insert(monitor.id)
            let panel = panels[monitor.id] ?? BarPanel(onSelect: onSelect)
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
