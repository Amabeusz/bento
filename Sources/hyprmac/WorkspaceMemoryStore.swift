import CoreGraphics
import Foundation
import HyprCore

@MainActor
final class WorkspaceMemoryStore {
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("hyprmac/workspaces.json")
    private var written: [WindowMemory]?

    func load() -> [WindowMemory] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([WindowMemory].self, from: data)
        else { return [] }
        let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        let existing = Set(list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
        written = entries
        return entries.filter { existing.contains($0.id) }
    }

    func save(_ entries: [WindowMemory]) {
        guard entries != written else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? JSONEncoder().encode(entries).write(to: url, options: .atomic)) != nil else { return }
        written = entries
    }
}
