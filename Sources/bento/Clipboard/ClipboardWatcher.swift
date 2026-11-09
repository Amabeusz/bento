import AppKit
import BentoCore

@MainActor
final class ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private let store = ClipboardStore()
    private var history: ClipboardHistory
    private var lastChange: Int
    private var timer: Timer?

    init() {
        history = ClipboardHistory(limit: 200, entries: store.load())
        lastChange = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func matching(_ query: String) -> [String] {
        history.matching(query)
    }

    func put(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        check()
    }

    private func check() {
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        let types = pasteboard.types?.map(\.rawValue) ?? []
        guard isRecordable(types: types), let text = pasteboard.string(forType: .string) else { return }
        let before = history
        history.record(text)
        if history != before { store.save(history.entries) }
    }
}
