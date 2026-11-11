import AppKit
import BentoCore

@MainActor
final class ClipboardWatcher {
    private static let maxImageBytes = 10 * 1024 * 1024
    private static let richTypes: [NSPasteboard.PasteboardType] = [.rtf, .html]
    private static let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
    private let pasteboard = NSPasteboard.general
    private let store = ClipboardStore()
    private var history: ClipboardHistory
    private var lastChange: Int
    private var timer: Timer?
    private var images: [String: NSImage] = [:]

    init() {
        history = ClipboardHistory(limit: 200, entries: store.load())
        lastChange = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func matching(_ query: String) -> [ClipEntry] {
        history.matching(query)
    }

    func image(for entry: ClipEntry) -> NSImage? {
        guard entry.kind == .image else { return nil }
        if let cached = images[entry.key] { return cached }
        let items = store.items(for: entry.key)
        let image = Self.imageTypes.lazy.compactMap { items[$0].flatMap(NSImage.init(data:)) }.first
        images[entry.key] = image
        return image
    }

    func put(_ entry: ClipEntry, plain: Bool) {
        pasteboard.clearContents()
        switch entry.kind {
        case .files:
            pasteboard.writeObjects(entry.text.split(separator: "\n").map { NSURL(fileURLWithPath: String($0)) })
        case .image:
            for (type, data) in store.items(for: entry.key) { pasteboard.setData(data, forType: type) }
        case .text:
            if !plain { for (type, data) in store.items(for: entry.key) { pasteboard.setData(data, forType: type) } }
            pasteboard.setString(entry.text, forType: .string)
        }
        if entry.secret { pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(concealedType)) }
        lastChange = pasteboard.changeCount
        history.touch(entry.key, at: Date().timeIntervalSince1970)
        save()
    }

    func setLimit(_ limit: Int) {
        guard limit != history.limit else { return }
        forget(history.setLimit(limit))
    }

    func togglePin(_ key: String) {
        history.togglePin(key)
        save()
    }

    func remove(_ key: String) {
        forget(history.remove(key))
    }

    func clear() {
        forget(history.clear())
    }

    private func check() {
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        guard let entry = capture() else { return }
        forget(history.record(entry.entry))
        guard let stored = history.entries.first(where: { $0.key == entry.entry.key }) else { return }
        if stored.secret { store.delete([stored.key]) } else { store.write(entry.items, for: stored.key) }
    }

    private func capture() -> (entry: ClipEntry, items: [NSPasteboard.PasteboardType: Data])? {
        let types = pasteboard.types ?? []
        let string = pasteboard.string(forType: .string)
        let kind = clipCapture(types: types.map(\.rawValue), text: string)
        guard kind != .skip else { return nil }
        let app = NSWorkspace.shared.frontmostApplication?.localizedName
        let now = Date().timeIntervalSince1970
        let secret = kind == .secret

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let paths = urls.map(\.path).joined(separator: "\n")
            let key = ClipboardStore.key(Data(("files:" + paths).utf8))
            return (ClipEntry(key: key, kind: .files, text: paths, app: app, at: now), [:])
        }
        if let string {
            var items: [NSPasteboard.PasteboardType: Data] = [:]
            for type in Self.richTypes where types.contains(type) { items[type] = pasteboard.data(forType: type) }
            let key = ClipboardStore.key(Data(string.utf8))
            return (ClipEntry(key: key, text: string, app: app, at: now, secret: secret), items)
        }
        guard let type = Self.imageTypes.first(where: types.contains), let data = pasteboard.data(forType: type),
              data.count <= Self.maxImageBytes
        else { return nil }
        return (ClipEntry(key: ClipboardStore.key(data), kind: .image, text: "", app: app, at: now), [type: data])
    }

    private func forget(_ keys: [String]) {
        store.delete(keys)
        keys.forEach { images[$0] = nil }
        save()
    }

    private func save() {
        store.save(history.persistable)
    }
}
