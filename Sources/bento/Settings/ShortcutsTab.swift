import AppKit
import BentoCore
import SwiftUI

private struct ShortcutAction: Hashable {
    let title: String
    let dispatcher: String
    var args = ""

    func matches(_ bind: EditableBind) -> Bool {
        bind.dispatcher.lowercased() == dispatcher && normalized(bind.args) == args
    }
}

private func normalized(_ args: String) -> String {
    args.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

private let directions = [("l", "left"), ("r", "right"), ("u", "up"), ("d", "down")]

private let catalog: [(title: String, actions: [ShortcutAction])] = [
    ("Windows",
     directions.map { ShortcutAction(title: "Focus \($0.1)", dispatcher: "movefocus", args: $0.0) }
        + directions.map { ShortcutAction(title: "Move window \($0.1)", dispatcher: "movewindow", args: $0.0) }
        + [
            ShortcutAction(title: "Grow window", dispatcher: "resizeactive", args: "50 50"),
            ShortcutAction(title: "Shrink window", dispatcher: "resizeactive", args: "-50 -50"),
            ShortcutAction(title: "Toggle split", dispatcher: "togglesplit"),
            ShortcutAction(title: "Toggle fullscreen", dispatcher: "fullscreen"),
            ShortcutAction(title: "Toggle floating", dispatcher: "togglefloating"),
            ShortcutAction(title: "Close window", dispatcher: "killactive"),
        ]),
    ("Workspaces",
     (Array(1...9) + [0]).map { ShortcutAction(title: "Go to workspace \($0)", dispatcher: "workspace", args: "\($0)") }
        + (Array(1...9) + [0]).map {
            ShortcutAction(title: "Move window to workspace \($0)", dispatcher: "movetoworkspace", args: "\($0)")
        }
        + [ShortcutAction(title: "Move workspace to other monitor", dispatcher: "movecurrentworkspacetomonitor")]),
    ("Tools", [
        ShortcutAction(title: "Window overview", dispatcher: "overview"),
        ShortcutAction(title: "Clipboard history", dispatcher: "clipboard"),
        ShortcutAction(title: "Command palette", dispatcher: "palette"),
        ShortcutAction(title: "Open terminal", dispatcher: "terminal"),
    ]),
]

private let appDispatchers = ["focusorlaunch", "exec"]

private enum RecordTarget: Equatable {
    case mod
    case bind(EditableBind)
    case add(dispatcher: String, args: String)
}

struct ShortcutsTab: View {
    @Bindable var model: SettingsModel
    @State private var target: RecordTarget?
    @State private var held: NSEvent.ModifierFlags = []
    @State private var monitor: Any?

    var body: some View {
        let binds = model.binds
        Form {
            Section {
                LabeledContent("Shortcuts with $mod use") {
                    HStack(spacing: 12) {
                        Text(target == .mod ? (held.isEmpty ? "Hold modifiers…" : modLabel(modNames(held))) : modLabel(model.mod))
                            .foregroundStyle(target == .mod ? .secondary : .primary)
                        Button(target == .mod ? "Cancel" : "Record") { target == .mod ? stop() : start(.mod) }
                    }
                }
            } header: {
                Text("Modifier ($mod)")
            } footer: {
                Text("Click Record, hold the modifier keys you want and let go. Esc cancels.").foregroundStyle(.secondary)
            }
            ForEach(catalog, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.actions, id: \.self) { action in
                        row(action.title, binds.filter(action.matches),
                            add: .add(dispatcher: action.dispatcher, args: action.args))
                    }
                }
            }
            Section {
                ForEach(binds.filter { appDispatchers.contains($0.dispatcher.lowercased()) }) { bind in
                    appRow(bind)
                }
                let addApp = RecordTarget.add(dispatcher: "focusorlaunch", args: "Safari")
                Button(target == addApp ? "Press keys…" : "Add app shortcut") { start(addApp) }
                    .disabled(target != nil && target != addApp)
            } header: {
                Text("Apps")
            } footer: {
                Text("Open or focus: an app name, e.g. Safari. Run command: a shell command, e.g. open -na Ghostty.")
                    .foregroundStyle(.secondary)
            }
            let other = binds.filter { bind in
                !appDispatchers.contains(bind.dispatcher.lowercased())
                    && !catalog.contains { $0.actions.contains { $0.matches(bind) } }
            }
            if !other.isEmpty {
                Section("Other") {
                    ForEach(other) { bind in
                        row("\(bind.dispatcher) \(bind.args)", [bind], add: nil)
                    }
                }
            }
            Section {
            } footer: {
                Text("Click a shortcut to record it again, + to add another one. Holding $mod (\(modSymbols(model.mod))) "
                    + "saves it as $mod, so it follows the modifier above. Esc cancels.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onDisappear(perform: stop)
    }

    private func row(_ title: String, _ binds: [EditableBind], add: RecordTarget?) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                ForEach(binds) { bind in chip(bind) }
                if let add {
                    Button(target == add ? "Press keys…" : binds.isEmpty ? "Record" : "+") { start(add) }
                        .disabled(target != nil && target != add)
                }
            }
        }
    }

    private func appRow(_ bind: EditableBind) -> some View {
        HStack {
            Picker("", selection: Binding(get: { bind.dispatcher.lowercased() }, set: { d in
                var b = bind
                b.dispatcher = d
                model.setBind(b)
            })) {
                Text("Open or focus").tag("focusorlaunch")
                Text("Run command").tag("exec")
            }
            .labelsHidden()
            .fixedSize()
            TextField("", text: Binding(get: { bind.args }, set: { a in
                var b = bind
                b.args = a
                model.setBind(b)
            }))
            chip(bind)
        }
    }

    private func chip(_ bind: EditableBind) -> some View {
        HStack(spacing: 2) {
            Button(target == .bind(bind) ? "Press keys…" : describe(bind, mod: model.mod)) { start(.bind(bind)) }
                .disabled(target != nil && target != .bind(bind))
            Button {
                model.removeBind(bind)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .help("Remove this shortcut")
        }
    }

    private func start(_ newTarget: RecordTarget) {
        stop()
        target = newTarget
        held = []
        model.recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            let isKeyDown = event.type == .keyDown
            let code = event.keyCode
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            MainActor.assumeIsolated { handle(isKeyDown: isKeyDown, code: code, flags: flags) }
            return nil
        }
    }

    private func handle(isKeyDown: Bool, code: UInt16, flags: NSEvent.ModifierFlags) {
        guard let target else { return }
        if isKeyDown, code == 53, flags.isEmpty { return stop() }
        switch target {
        case .mod:
            if isKeyDown { return }
            if flags.isEmpty, !held.isEmpty {
                model.setMod(modNames(held))
                stop()
            } else {
                held.formUnion(flags)
            }
        case .bind(var bind):
            guard isKeyDown, let key = keyNames[CGKeyCode(code)] else { return }
            bind.mods = recordedMods(flags)
            bind.key = key
            model.setBind(bind)
            stop()
        case .add(let dispatcher, let args):
            guard isKeyDown, let key = keyNames[CGKeyCode(code)] else { return }
            model.addBind(EditableBind(mods: recordedMods(flags), key: key, dispatcher: dispatcher, args: args))
            stop()
        }
    }

    private func recordedMods(_ flags: NSEvent.ModifierFlags) -> String {
        let pressed = Set(modifierNames.filter { flags.contains($0.flag) }.map(\.name))
        let modSet = modNameSet(model.mod)
        guard !modSet.isEmpty, modSet.isSubset(of: pressed) else {
            return modifierNames.map(\.name).filter(pressed.contains).joined(separator: " ")
        }
        return (["$mod"] + modifierNames.map(\.name).filter { pressed.subtracting(modSet).contains($0) })
            .joined(separator: " ")
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if target != nil { model.recording = false }
        target = nil
        held = []
    }
}

private func modNameSet(_ mods: String) -> Set<String> {
    Set(mods.uppercased().split(whereSeparator: \.isWhitespace).map { $0 == "CMD" ? "SUPER" : String($0) })
}

private func modNames(_ flags: NSEvent.ModifierFlags) -> String {
    modifierNames.filter { flags.contains($0.flag) }.map(\.name).joined(separator: " ")
}

private func modLabel(_ mods: String) -> String {
    let names = modNameSet(mods)
    let macNames = ["CTRL": "Control", "ALT": "Option", "SHIFT": "Shift", "SUPER": "Command"]
    return modifierNames.filter { names.contains($0.name) }.map { "\($0.symbol) \(macNames[$0.name] ?? $0.name)" }
        .joined(separator: "  ")
}

private func modSymbols(_ mods: String) -> String {
    let names = modNameSet(mods)
    return modifierNames.filter { names.contains($0.name) }.map(\.symbol).joined()
}
