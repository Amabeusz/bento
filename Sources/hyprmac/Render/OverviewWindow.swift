import AppKit
import HyprCore
@preconcurrency import ScreenCaptureKit

struct OverviewScreen {
    let monitor: MonitorInfo
    let frame: NSRect
    let items: [OverviewItem]
}

@MainActor
final class OverviewManager {
    private let onPick: (WindowID) -> Void
    private let icon: (WindowID) -> NSImage?
    private let title: (WindowID) -> String?
    private var panels: [OverviewPanel] = []
    private var slots: [(panel: Int, thumb: Int, rect: Rect)] = []
    private var selection: Int?

    init(onPick: @escaping (WindowID) -> Void, icon: @escaping (WindowID) -> NSImage?, title: @escaping (WindowID) -> String?) {
        self.onPick = onPick
        self.icon = icon
        self.title = title
    }

    var isOpen: Bool { !panels.isEmpty }

    func show(_ screens: [OverviewScreen], focused: WindowID?) {
        close()
        for (p, screen) in screens.enumerated() {
            let m = screen.monitor
            let local = Rect(x: m.usable.x - m.frame.x, y: m.usable.y - m.frame.y, w: m.usable.w, h: m.usable.h).inset(by: 40)
            let rects = overviewGrid(sizes: screen.items.map(\.frame), in: local, gap: 30, label: OverviewView.labelHeight)
            let thumbs = zip(screen.items, rects).map { item, rect in
                Thumbnail(item: item, rect: rect, icon: icon(item.id), title: title(item.id) ?? "")
            }
            for (t, r) in rects.enumerated() {
                slots.append((p, t, Rect(x: r.x + m.frame.x, y: r.y + m.frame.y, w: r.w, h: r.h)))
            }
            let panel = OverviewPanel(frame: screen.frame, thumbnails: thumbs)
            panel.view.onClick = { [weak self] id in self?.finish(id) }
            panel.view.onKey = { [weak self] code in self?.key(code) ?? false }
            panels.append(panel)
        }
        let mouse = panels.firstIndex { $0.frame.contains(NSEvent.mouseLocation) }
        selection = slots.firstIndex { panels[$0.panel].view.thumbnails[$0.thumb].item.id == focused }
            ?? slots.firstIndex { $0.panel == mouse } ?? slots.indices.first
        mouse.map { panels[$0].makeKey() } ?? panels.first?.makeKey()
        showSelection()
        capture()
    }

    func close() {
        panels.forEach { $0.close() }
        panels = []
        slots = []
        selection = nil
    }

    private func finish(_ id: WindowID?) {
        close()
        if let id { onPick(id) }
    }

    private func key(_ code: UInt16) -> Bool {
        let directions: [UInt16: Direction] = [123: .left, 124: .right, 125: .down, 126: .up]
        switch code {
        case 53:
            finish(nil)
        case 36, 76, 49:
            finish(selection.map { panels[slots[$0].panel].view.thumbnails[slots[$0].thumb].item.id })
        default:
            guard let dir = directions[code] else { return false }
            if let s = selection, let next = overviewNeighbor(from: s, in: slots.map(\.rect), toward: dir) {
                selection = next
                showSelection()
            }
        }
        return true
    }

    private func showSelection() {
        for (p, panel) in panels.enumerated() {
            panel.view.selected = selection.flatMap { slots[$0].panel == p ? slots[$0].thumb : nil }
        }
    }

    private func capture() {
        guard CGPreflightScreenCaptureAccess() else { return }
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let wanted = Set(slots.map { panels[$0.panel].view.thumbnails[$0.thumb].item.id })
        Task { [weak self] in
            guard let content = try? await SCShareableContent.current else { return }
            for window in content.windows where wanted.contains(window.windowID) {
                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int(window.frame.width * scale))
                configuration.height = max(1, Int(window.frame.height * scale))
                configuration.captureResolution = .best
                configuration.scalesToFit = true
                configuration.showsCursor = false
                configuration.ignoreShadowsSingleWindow = true
                let image = try? await SCScreenshotManager.captureImage(
                    contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
                guard let self, let image else { continue }
                self.panels.forEach { $0.view.setImage(image, for: window.windowID) }
            }
        }
    }
}

struct Thumbnail {
    let item: OverviewItem
    let rect: Rect
    let icon: NSImage?
    let title: String
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
private final class OverviewPanel {
    private let panel: KeyPanel
    let view: OverviewView
    let frame: NSRect

    init(frame: NSRect, thumbnails: [Thumbnail]) {
        self.frame = frame
        panel = KeyPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        view = OverviewView(frame: NSRect(origin: .zero, size: frame.size), thumbnails: thumbnails)
        panel.contentView = view
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func makeKey() {
        panel.makeKey()
        panel.makeFirstResponder(view)
    }

    func close() {
        panel.orderOut(nil)
        panel.close()
    }
}

@MainActor
private final class OverviewView: NSView {
    static let labelHeight = 28.0
    let thumbnails: [Thumbnail]
    var onClick: ((WindowID?) -> Void)?
    var onKey: ((UInt16) -> Bool)?
    var selected: Int? {
        didSet { if selected != oldValue { needsDisplay = true } }
    }
    private var images: [WindowID: CGImage] = [:]

    init(frame: NSRect, thumbnails: [Thumbnail]) {
        self.thumbnails = thumbnails
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func setImage(_ image: CGImage, for id: WindowID) {
        guard thumbnails.contains(where: { $0.item.id == id }) else { return }
        images[id] = image
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onClick?(thumbnails.first { rect($0).contains(p) }?.item.id)
    }

    override func keyDown(with event: NSEvent) {
        if onKey?(event.keyCode) != true { super.keyDown(with: event) }
    }

    private func rect(_ t: Thumbnail) -> NSRect {
        NSRect(x: t.rect.x, y: t.rect.y, width: t.rect.w, height: t.rect.h)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.6).setFill()
        bounds.fill()
        NSGraphicsContext.current?.imageInterpolation = .high
        for (i, t) in thumbnails.enumerated() {
            let r = rect(t)
            let clip = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            if let image = images[t.item.id] {
                NSImage(cgImage: image, size: r.size).draw(in: r)
            } else {
                drawPlaceholder(t, in: r)
            }
            NSGraphicsContext.restoreGraphicsState()
            if i == selected {
                let ring = NSBezierPath(roundedRect: r.insetBy(dx: -5, dy: -5), xRadius: 14, yRadius: 14)
                ring.lineWidth = 4
                NSColor.controlAccentColor.setStroke()
                ring.stroke()
            }
            drawBadge(t.item.workspace, at: r)
            drawLabel(t, above: r)
        }
    }

    private func drawLabel(_ t: Thumbnail, above r: NSRect) {
        let side = 18.0
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let text = NSAttributedString(string: t.title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: style,
        ])
        let width = min(text.size().width, max(0, r.width - side - 6))
        let left = r.midX - (side + 6 + width) / 2
        let y = r.minY - Self.labelHeight
        t.icon?.draw(in: NSRect(x: left, y: y + (Self.labelHeight - side) / 2, width: side, height: side),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        text.draw(in: NSRect(x: left + side + 6, y: y + (Self.labelHeight - 18) / 2, width: width, height: 18))
    }

    private func drawPlaceholder(_ t: Thumbnail, in r: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.9).setFill()
        r.fill()
        let side = min(96, r.width / 3, r.height / 3)
        let iconRect = NSRect(x: r.midX - side / 2, y: r.midY - side / 2 - 12, width: side, height: side)
        t.icon?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        let text = NSAttributedString(string: t.title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.labelColor,
        ])
        let width = min(text.size().width, r.width - 16)
        text.draw(with: NSRect(x: r.midX - width / 2, y: iconRect.maxY + 8, width: width, height: 18),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    private func drawBadge(_ number: Int, at r: NSRect) {
        let text = NSAttributedString(string: "\(number)", attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .bold), .foregroundColor: NSColor.white,
        ])
        let size = text.size()
        let side = max(26, size.width + 12)
        let badge = NSRect(x: r.minX + 8, y: r.minY + 8, width: side, height: 26)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 13, yRadius: 13).fill()
        text.draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2))
    }
}
