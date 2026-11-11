import AppKit
import BentoCore

@MainActor
final class CommandPalettePanel: NSObject, NSSearchFieldDelegate, NSWindowDelegate {
    private static let width = 620.0
    private static let padding = 12.0
    private static let fieldHeight = 30.0
    private let commands: () -> [PaletteCommand]
    private let isOn: (PaletteCommand) -> Bool
    private let run: (PaletteCommand) -> Void
    private var panel: PaletteKeyPanel?
    private var recent: [String] = []
    private let field = NSSearchField()
    private let list = PaletteListView()

    init(commands: @escaping () -> [PaletteCommand], isOn: @escaping (PaletteCommand) -> Bool,
         run: @escaping (PaletteCommand) -> Void) {
        self.commands = commands
        self.isOn = isOn
        self.run = run
        super.init()
        field.delegate = self
        field.placeholderString = "Search Bento commands"
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 16)
        list.isOn = isOn
        list.onClick = { [weak self] row in self?.pick(row) }
    }

    var isOpen: Bool { panel != nil }

    func show() {
        close()
        let p = Self.padding
        let listHeight = PaletteListView.rowHeight * Double(PaletteListView.visibleRows)
        let height = p * 3 + Self.fieldHeight + listHeight
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: Self.width, height: height)
        let frame = NSRect(x: area.midX - Self.width / 2, y: area.midY - height / 2 + area.height / 8,
                           width: Self.width, height: height)

        let panel = PaletteKeyPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: frame.size))
        glass.cornerRadius = 16
        let background = NSView(frame: glass.bounds)
        glass.contentView = background
        field.frame = NSRect(x: p, y: height - p - Self.fieldHeight, width: Self.width - p * 2, height: Self.fieldHeight)
        list.frame = NSRect(x: p, y: p, width: Self.width - p * 2, height: listHeight)
        background.addSubview(field)
        background.addSubview(list)
        panel.contentView = glass

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
        list.items = rankCommands(commands(), query: field.stringValue, recent: recent)
        list.select(0)
    }

    private func pick(_ row: Int) {
        guard list.items.indices.contains(row) else { return }
        let command = list.items[row]
        recent.removeAll { $0 == command.id }
        recent.insert(command.id, at: 0)
        recent = Array(recent.prefix(5))
        close()
        run(command)
    }
}

private final class PaletteKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
private final class PaletteListView: NSView {
    static let rowHeight = 34.0
    static let visibleRows = 9
    var items: [PaletteCommand] = [] { didSet { needsDisplay = true } }
    var isOn: (PaletteCommand) -> Bool = { _ in false }
    var onClick: ((Int) -> Void)?
    private(set) var selection = 0
    private var top = 0

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
        let font = NSFont.systemFont(ofSize: 14)
        let small = NSFont.systemFont(ofSize: 12)
        guard !items.isEmpty else {
            "No matching command".draw(at: NSPoint(x: 10, y: 9), withAttributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
            return
        }
        for (offset, command) in items.dropFirst(top).prefix(Self.visibleRows).enumerated() {
            let row = NSRect(x: 0, y: Double(offset) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
            let selected = top + offset == selection
            if selected {
                NSColor.selectedContentBackgroundColor.setFill()
                NSBezierPath(roundedRect: row, xRadius: 7, yRadius: 7).fill()
            }
            let text = selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor
            let dim = selected ? NSColor.alternateSelectedControlTextColor : NSColor.secondaryLabelColor
            if let icon = NSImage(systemSymbolName: command.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 15, weight: .regular).applying(.init(paletteColors: [dim]))) {
                icon.draw(in: NSRect(x: row.minX + 10, y: row.midY - 9, width: 18, height: 18))
            }
            var right = command.shortcut ?? ""
            if isOn(command) { right = "✓  " + right }
            let info = right as NSString
            let infoWidth = info.size(withAttributes: [.font: small]).width
            info.draw(at: NSPoint(x: row.maxX - infoWidth - 12, y: row.midY - 8), withAttributes: [.font: small, .foregroundColor: dim])
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            (command.title as NSString).draw(
                in: NSRect(x: row.minX + 40, y: row.midY - 9, width: row.maxX - infoWidth - 60 - row.minX, height: 20),
                withAttributes: [.font: font, .paragraphStyle: style, .foregroundColor: text])
        }
    }
}
