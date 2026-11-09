import AppKit
import BentoCore

struct ClipboardActions {
    let entries: (String) -> [ClipEntry]
    let image: (ClipEntry) -> NSImage?
    let pick: (ClipEntry, Bool) -> Void
    let togglePin: (String) -> Void
    let remove: (String) -> Void
}

@MainActor
final class ClipboardPanel: NSObject, NSSearchFieldDelegate, NSWindowDelegate {
    private static let listWidth = 520.0
    private static let previewWidth = 380.0
    private static let padding = 12.0
    private static let fieldHeight = 28.0
    private let actions: ClipboardActions
    private var panel: ClipboardKeyPanel?
    private var monitor: Any?
    private let field = NSSearchField()
    private let list: ClipboardListView
    private let preview: ClipboardPreviewView

    init(actions: ClipboardActions) {
        self.actions = actions
        list = ClipboardListView(image: actions.image)
        preview = ClipboardPreviewView(image: actions.image)
        super.init()
        field.delegate = self
        field.placeholderString = "Search clipboard history"
        field.focusRingType = .none
        list.onClick = { [weak self] row in self?.pick(row, plain: false) }
        list.onSelect = { [weak self] entry in self?.preview.entry = entry }
    }

    var isOpen: Bool { panel != nil }

    func show() {
        close()
        let p = Self.padding
        let listHeight = ClipboardListView.rowHeight * Double(ClipboardListView.visibleRows)
        let width = p * 3 + Self.listWidth + Self.previewWidth
        let height = p * 3 + Self.fieldHeight + listHeight
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: width, height: height)
        let frame = NSRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)

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
        field.frame = NSRect(x: p, y: height - p - Self.fieldHeight, width: Self.listWidth, height: Self.fieldHeight)
        list.frame = NSRect(x: p, y: p, width: Self.listWidth, height: listHeight)
        preview.frame = NSRect(x: p * 2 + Self.listWidth, y: p, width: Self.previewWidth, height: height - p * 2)
        [field, list, preview].forEach(background.addSubview)
        panel.contentView = background

        field.stringValue = ""
        refresh()
        self.panel = panel
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            let code = event.keyCode
            let digit = event.charactersIgnoringModifiers.flatMap(Int.init)
            let handled = MainActor.assumeIsolated { self?.handle(mods, code, digit) == true }
            return handled ? nil : event
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(field)
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
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
        case #selector(NSResponder.insertNewline(_:)): pick(list.selection, plain: false)
        case #selector(NSResponder.cancelOperation(_:)): close()
        default: return false
        }
        return true
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func handle(_ mods: NSEvent.ModifierFlags, _ code: UInt16, _ digit: Int?) -> Bool {
        let selected = list.items.indices.contains(list.selection) ? list.items[list.selection] : nil
        switch (mods, code) {
        case (.shift, 36), (.shift, 76):
            pick(list.selection, plain: true)
        case (.command, _):
            guard let digit, (1...9).contains(digit) else { return false }
            pick(digit - 1, plain: false)
        case (.option, 35):
            guard let selected else { return true }
            actions.togglePin(selected.key)
            refresh(keeping: selected.key)
        case (.option, 51):
            guard let selected else { return true }
            actions.remove(selected.key)
            refresh(keeping: nil, at: list.selection)
        default:
            return false
        }
        return true
    }

    private func refresh(keeping key: String? = nil, at row: Int = 0) {
        list.items = actions.entries(field.stringValue)
        list.select(key.flatMap { k in list.items.firstIndex { $0.key == k } } ?? row)
    }

    private func pick(_ row: Int, plain: Bool) {
        guard list.items.indices.contains(row) else { return }
        let entry = list.items[row]
        close()
        actions.pick(entry, plain)
    }
}

private final class ClipboardKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private func appIcon(_ name: String?) -> NSImage? {
    guard let name else { return nil }
    return NSWorkspace.shared.runningApplications.first { $0.localizedName == name }?.icon
}

private func summary(of entry: ClipEntry, image: NSImage?) -> String {
    switch entry.kind {
    case .text:
        return entry.displayText.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ⏎ ")
    case .image:
        return image.map { "Image \(Int($0.size.width))×\(Int($0.size.height))" } ?? "Image"
    case .files:
        let names = entry.text.split(separator: "\n").map { ($0 as NSString).lastPathComponent }
        return names.count > 1 ? "\(names[0]) + \(names.count - 1) more" : names.first ?? ""
    }
}

@MainActor
private final class ClipboardListView: NSView {
    static let rowHeight = 30.0
    static let visibleRows = 14
    private let image: (ClipEntry) -> NSImage?
    var items: [ClipEntry] = [] { didSet { needsDisplay = true } }
    private(set) var selection = 0
    private var top = 0
    var onClick: ((Int) -> Void)?
    var onSelect: ((ClipEntry?) -> Void)?

    init(image: @escaping (ClipEntry) -> NSImage?) {
        self.image = image
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func select(_ row: Int) {
        selection = clampedSelection(row, count: items.count)
        if selection < top { top = selection }
        if selection >= top + Self.visibleRows { top = selection - Self.visibleRows + 1 }
        if items.count <= Self.visibleRows { top = 0 }
        needsDisplay = true
        onSelect?(items.indices.contains(selection) ? items[selection] : nil)
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onClick?(top + Int(p.y / Self.rowHeight))
    }

    override func draw(_ dirtyRect: NSRect) {
        let font = NSFont.systemFont(ofSize: 13)
        let small = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        guard !items.isEmpty else {
            "No clipboard history".draw(at: NSPoint(x: 8, y: 6), withAttributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
            return
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let now = Date().timeIntervalSince1970
        for (offset, entry) in items.dropFirst(top).prefix(Self.visibleRows).enumerated() {
            let index = top + offset
            let row = NSRect(x: 0, y: Double(offset) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
            let selected = index == selection
            if selected {
                NSColor.selectedContentBackgroundColor.setFill()
                NSBezierPath(roundedRect: row, xRadius: 6, yRadius: 6).fill()
            }
            let text = selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor
            let dim = selected ? NSColor.alternateSelectedControlTextColor : NSColor.secondaryLabelColor
            let picture = image(entry)
            let icon: NSImage? = switch entry.kind {
            case .image: picture
            case .files: entry.text.split(separator: "\n").first.map { NSWorkspace.shared.icon(forFile: String($0)) }
            case .text: appIcon(entry.app)
            }
            icon?.draw(in: NSRect(x: row.minX + 6, y: row.minY + 5, width: 20, height: 20))

            var right = [relativeTime(now - entry.lastCopied)]
            if index < 9 { right.append("⌘\(index + 1)") }
            let info = right.joined(separator: "  ") as NSString
            let infoWidth = info.size(withAttributes: [.font: small]).width
            info.draw(at: NSPoint(x: row.maxX - infoWidth - 8, y: row.minY + 8), withAttributes: [.font: small, .foregroundColor: dim])
            var textX = row.minX + 32
            if entry.pinned, let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "pinned")?
                .withSymbolConfiguration(.init(paletteColors: [dim])) {
                pin.draw(in: NSRect(x: textX, y: row.minY + 9, width: 10, height: 12))
                textX += 16
            }
            (summary(of: entry, image: picture) as NSString).draw(
                in: NSRect(x: textX, y: row.minY + 7, width: row.maxX - infoWidth - 16 - textX, height: 18),
                withAttributes: [.font: font, .paragraphStyle: style, .foregroundColor: text])
        }
    }
}

@MainActor
private final class ClipboardPreviewView: NSView {
    private let image: (ClipEntry) -> NSImage?
    var entry: ClipEntry? { didSet { needsDisplay = true } }
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init(image: @escaping (ClipEntry) -> NSImage?) {
        self.image = image
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        guard let entry else { return }
        let small = NSFont.systemFont(ofSize: 11)
        let details = [
            ("App", entry.app ?? "—"),
            ("First copied", formatter.string(from: Date(timeIntervalSince1970: entry.firstCopied))),
            ("Last copied", formatter.string(from: Date(timeIntervalSince1970: entry.lastCopied))),
            ("Copies", "\(entry.copies)"),
        ]
        let detailsHeight = Double(details.count) * 18 + 12
        let content = bounds.insetBy(dx: 12, dy: 12)
        let body = NSRect(x: content.minX, y: content.minY, width: content.width, height: content.height - detailsHeight)
        for (i, (label, value)) in details.enumerated() {
            let y = body.maxY + 12 + Double(i) * 18
            (label as NSString).draw(at: NSPoint(x: content.minX, y: y), withAttributes: [.font: small, .foregroundColor: NSColor.secondaryLabelColor])
            (value as NSString).draw(at: NSPoint(x: content.minX + 90, y: y), withAttributes: [.font: small, .foregroundColor: NSColor.labelColor])
        }

        switch entry.kind {
        case .image:
            guard let picture = image(entry), picture.size.width > 0, picture.size.height > 0 else { return }
            let scale = min(body.width / picture.size.width, body.height / picture.size.height, 1)
            let size = NSSize(width: picture.size.width * scale, height: picture.size.height * scale)
            picture.draw(in: NSRect(x: body.midX - size.width / 2, y: body.minY, width: size.width, height: size.height),
                         from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        case .text, .files:
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byWordWrapping
            let font = entry.kind == .text && !entry.secret ? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                : NSFont.systemFont(ofSize: 13)
            (String(entry.displayText.prefix(5000)) as NSString).draw(
                with: body, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                attributes: [.font: font, .paragraphStyle: style, .foregroundColor: NSColor.labelColor])
        }
    }
}

