import AppKit
import BentoCore
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class SettingsModel {
    private(set) var editor: ConfigEditor
    var saveError: String?
    var configError: String?
    var recording = false {
        didSet { onRecording(recording) }
    }
    @ObservationIgnored var launchAtLogin: () -> Bool = { false }
    @ObservationIgnored var setLaunchAtLogin: (Bool) -> Void = { _ in }
    @ObservationIgnored var onRecording: (Bool) -> Void = { _ in }
    @ObservationIgnored private let url: URL
    @ObservationIgnored private var pending: DispatchWorkItem?
    @ObservationIgnored let defaults = Config()

    init(url: URL) {
        self.url = url
        editor = ConfigEditor(text: (try? String(contentsOf: url, encoding: .utf8)) ?? defaultConfigText)
    }

    var hasPendingSave: Bool { pending != nil }

    func reload() {
        guard pending == nil, let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        if text != editor.text { editor = ConfigEditor(text: text) }
    }

    func openFile() {
        guard !NSWorkspace.shared.open(url),
              let textEditor = NSWorkspace.shared.urlForApplication(toOpen: .plainText) else { return }
        NSWorkspace.shared.open([url], withApplicationAt: textEditor, configuration: NSWorkspace.OpenConfiguration())
    }

    func string(_ key: String) -> String? { editor.value(key) }

    func number(_ key: String, _ fallback: Double) -> Double {
        editor.value(key).flatMap(Double.init) ?? fallback
    }

    func flag(_ key: String, _ fallback: Bool) -> Bool {
        switch editor.value(key) {
        case "true", "1": true
        case "false", "0": false
        default: fallback
        }
    }

    func color(_ key: String, _ fallback: RGBA) -> RGBA {
        editor.value(key).flatMap(parseColor) ?? fallback
    }

    func set(_ key: String, _ value: String) {
        guard editor.value(key) != value else { return }
        editor.set(key, value)
        scheduleSave()
    }

    func set(_ key: String, number: Double) {
        set(key, number.rounded() == number ? String(Int(number)) : String(number))
    }

    func set(_ key: String, flag: Bool) {
        set(key, flag ? "true" : "false")
    }

    func set(_ key: String, color: RGBA) {
        set(key, formatColor(color))
    }

    func gradient(_ key: String, _ fallback: Gradient) -> Gradient? {
        guard let raw = editor.value(key) else { return fallback }
        return parseGradient(raw)
    }

    func set(_ key: String, gradient: Gradient) {
        set(key, formatGradient(gradient))
    }

    func insets(_ key: String, _ fallback: Insets) -> Insets? {
        guard let raw = editor.value(key) else { return fallback }
        return parseInsets(raw)
    }

    func set(_ key: String, insets: Insets, perSide: Bool) {
        set(key, formatInsets(insets, perSide: perSide))
    }

    func remove(_ key: String) {
        guard editor.value(key) != nil else { return }
        editor.remove(key)
        scheduleSave()
    }

    var mod: String { editor.mod ?? "CTRL ALT" }

    func setMod(_ mods: String) {
        editor.setMod(mods)
        scheduleSave()
    }

    var binds: [EditableBind] { editor.binds }

    func setBind(_ bind: EditableBind) {
        editor.setBind(bind)
        scheduleSave()
    }

    func addBind(_ bind: EditableBind) {
        editor.addBind(bind)
        scheduleSave()
    }

    func removeBind(_ bind: EditableBind) {
        editor.removeBind(at: bind.line)
        scheduleSave()
    }

    private func scheduleSave() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.save() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func save() {
        pending = nil
        do {
            try editor.text.write(to: url, atomically: true, encoding: .utf8)
            saveError = nil
        } catch {
            saveError = "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}
