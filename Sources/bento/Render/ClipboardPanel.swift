import AppKit
import BentoCore

@MainActor
final class ClipboardPanel: NSObject, NSSearchFieldDelegate, NSWindowDelegate {
    private static let width = 560.0
    private static let padding = 12.0
    private static let fieldHeight = 28.0
    private let entries: (String) -> [String]
    private let onPick: (String) -> Void
    private var panel: ClipboardKeyPanel?
    private let field = NSSearchField()
    private let list = ClipboardListView()

    init(entries: @escaping (String) -> [String], onPick: @escaping (String) -> Void) {
        self.entries = entries
        self.onPick = onPick
        super.init()
        field.delegate = self
        field.placeholderString = "Search clipboard history"
        field.focusRingType = .none
        list.onClick = { [weak self] row in self?.pick(row) }
    }

    var isOpen: Bool { panel != nil }

    func show() {
        close()
        let height = Self.padding * 3 + Self.fieldHeight + ClipboardListView.rowHeight * Double(ClipboardListView.visibleRows)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: Self.width, height: height)
        let frame = NSRect(x: area.midX - Self.width / 2, y: area.midY - height / 2, width: Self.width, height: height)

        let panel = ClipboardKeyPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        field.frame = NSRect(x: Self.padding, y: height - Self.padding - Self.fieldHeight,
                             width: Self.width - Self.padding * 2, height: Self.fieldHeight)
        list.frame = NSRect(x: Self.padding, y: Self.padding, width: Self.width - Self.padding * 2,
                            height: ClipboardListView.rowHeight * Double(ClipboardListView.visibleRows))
        background.addSubview(field)
        background.addSubview(list)
        panel.contentView = background

        field.stringValue = ""
        refresh()
        self.panel = panel
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(field)
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        panel.orderOut(nil)
        panel.close()
    }

    func controlTextDidChange(_ obj: Notification) {
        refresh()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)): list.select(list.selection - 1)
        case #selector(NSResponder.moveDown(_:)): list.select(list.selection + 1)
        case #selector(NSResponder.insertNewline(_:)): pick(list.selection)
        case #selector(NSResponder.cancelOperation(_:)): close()
        default: return false
        }
        return true
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func refresh() {
        list.items = entries(field.stringValue)
        list.select(0)
    }

    private func pick(_ row: Int) {
        guard list.items.indices.contains(row) else { return }
        let text = list.items[row]
        close()
        onPick(text)
    }
}

private final class ClipboardKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
private final class ClipboardListView: NSView {
    static let rowHeight = 28.0
    static let visibleRows = 12
    var items: [String] = [] { didSet { needsDisplay = true } }
    private(set) var selection = 0
    private var top = 0
    var onClick: ((Int) -> Void)?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func select(_ row: Int) {
        selection = clampedSelection(row, count: items.count)
        if selection < top { top = selection }
        if selection >= top + Self.visibleRows { top = selection - Self.visibleRows + 1 }
        if items.count <= Self.visibleRows { top = 0 }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onClick?(top + Int(p.y / Self.rowHeight))
    }

    override func draw(_ dirtyRect: NSRect) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let font = NSFont.systemFont(ofSize: 13)
        guard !items.isEmpty else {
            "No clipboard history".draw(at: NSPoint(x: 8, y: 6), withAttributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
            return
        }
        for (offset, text) in items.dropFirst(top).prefix(Self.visibleRows).enumerated() {
            let row = NSRect(x: 0, y: Double(offset) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
            let selected = top + offset == selection
            if selected {
                NSColor.selectedContentBackgroundColor.setFill()
                NSBezierPath(roundedRect: row, xRadius: 6, yRadius: 6).fill()
            }
            let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ⏎ ")
            line.draw(in: row.insetBy(dx: 8, dy: 6), withAttributes: [
                .font: font, .paragraphStyle: style,
                .foregroundColor: selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor,
            ])
        }
    }
}
