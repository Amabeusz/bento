import AppKit
import BentoCore
import CryptoKit

@MainActor
final class ClipboardStore {
    private let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("bento")
    private var url: URL { root.appendingPathComponent("clipboard.json") }
    private var dataRoot: URL { root.appendingPathComponent("clipboard") }

    func load() -> [ClipEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        if let entries = try? JSONDecoder().decode([ClipEntry].self, from: data) { return entries }
        guard let texts = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        let now = Date().timeIntervalSince1970
        return texts.enumerated().map { i, text in
            ClipEntry(key: Self.key(Data(text.utf8)), text: text, at: now - Double(i), secret: looksLikeSecret(text))
        }
    }

    func save(_ entries: [ClipEntry]) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }

    func write(_ items: [NSPasteboard.PasteboardType: Data], for key: String) {
        guard !items.isEmpty else { return }
        let dir = dataRoot.appendingPathComponent(key)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (type, data) in items { try? data.write(to: dir.appendingPathComponent(type.rawValue), options: .atomic) }
    }

    func items(for key: String) -> [NSPasteboard.PasteboardType: Data] {
        let dir = dataRoot.appendingPathComponent(key)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        var items: [NSPasteboard.PasteboardType: Data] = [:]
        for name in names {
            items[NSPasteboard.PasteboardType(name)] = try? Data(contentsOf: dir.appendingPathComponent(name))
        }
        return items
    }

    func delete(_ keys: [String]) {
        for key in keys { try? FileManager.default.removeItem(at: dataRoot.appendingPathComponent(key)) }
    }

    static func key(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
