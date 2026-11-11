import AppKit
import BentoCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.saveError ?? model.configError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
            }
            TabView {
                AppearanceTab(model: model).tabItem { Label("Appearance", systemImage: "paintbrush") }
                BehaviorTab(model: model).tabItem { Label("Behavior", systemImage: "cursorarrow.motionlines") }
                ShortcutsTab(model: model).tabItem { Label("Shortcuts", systemImage: "keyboard") }
                ClipboardTab(model: model).tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            }
            .padding(.top, model.saveError ?? model.configError == nil ? 36 : 8)
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}

private struct NumberRow: View {
    let title: String
    let key: String
    let range: ClosedRange<Double>
    let model: SettingsModel
    let fallback: Double

    var body: some View {
        let value = Binding(get: { model.number(key, fallback) }, set: { model.set(key, number: $0.rounded()) })
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: 1)
                Text("\(Int(value.wrappedValue))").monospacedDigit().frame(width: 36, alignment: .trailing)
            }
        }
    }
}

private struct FlagRow: View {
    let title: String
    let key: String
    let model: SettingsModel
    let fallback: Bool

    var body: some View {
        Toggle(title, isOn: Binding(get: { model.flag(key, fallback) }, set: { model.set(key, flag: $0) }))
    }
}

private struct ColorRow: View {
    let title: String
    let key: String
    let model: SettingsModel
    let fallback: RGBA

    var body: some View {
        ColorPicker(title, selection: Binding(
            get: { model.color(key, fallback).color },
            set: { model.set(key, color: RGBA($0)) }), supportsOpacity: true)
    }
}

private struct BorderColorRow: View {
    let title: String
    let key: String
    let model: SettingsModel

    var body: some View {
        let raw = model.string(key) ?? ""
        if raw.isEmpty || parseColor(raw) != nil {
            ColorPicker(title, selection: Binding(
                get: { (parseColor(raw) ?? RGBA(hex: 0x585b70aa)).color },
                set: { model.set(key, color: RGBA($0)) }), supportsOpacity: true)
        } else {
            LabeledContent(title) {
                TextField("rgba(…) rgba(…) 135deg", text: Binding(get: { raw }, set: { model.set(key, $0) }))
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}

private struct OptionalNumberRow: View {
    let title: String
    let key: String
    let range: ClosedRange<Double>
    let model: SettingsModel
    let automatic: Double

    var body: some View {
        let isAuto = model.string(key) == nil
        LabeledContent(title) {
            HStack {
                Toggle("Auto", isOn: Binding(
                    get: { isAuto },
                    set: { $0 ? model.remove(key) : model.set(key, number: automatic.rounded()) }))
                    .toggleStyle(.checkbox)
                Slider(value: Binding(get: { model.number(key, automatic) }, set: { model.set(key, number: $0.rounded()) }),
                       in: range, step: 1)
                    .disabled(isAuto)
                Text(isAuto ? "auto" : "\(Int(model.number(key, automatic)))").monospacedDigit().frame(width: 36, alignment: .trailing)
            }
        }
    }
}

private struct AppearanceTab: View {
    let model: SettingsModel

    var body: some View {
        let d = model.defaults
        Form {
            Section("Windows") {
                NumberRow(title: "Gap between windows", key: "general:gaps_in", range: 0...40, model: model, fallback: d.gapsIn)
                LabeledContent("Gap to screen edges") {
                    TextField("12 or top right bottom left", text: Binding(
                        get: { model.string("general:gaps_out") ?? "12" }, set: { model.set("general:gaps_out", $0) }))
                }
                NumberRow(title: "Border", key: "general:border_size", range: 0...10, model: model, fallback: d.borderSize)
                OptionalNumberRow(title: "Border of unfocused windows", key: "general:border_size_inactive", range: 0...10,
                                  model: model, automatic: model.number("general:border_size", d.borderSize))
                BorderColorRow(title: "Focused border color", key: "general:col.active_border", model: model)
                BorderColorRow(title: "Unfocused border color", key: "general:col.inactive_border", model: model)
                NumberRow(title: "Corner rounding", key: "decoration:rounding", range: 0...30, model: model, fallback: d.rounding)
            }
            Section("Island") {
                FlagRow(title: "Show the island", key: "bar:enabled", model: model, fallback: d.barEnabled)
                FlagRow(title: "App icons next to workspace numbers", key: "bar:icons", model: model, fallback: d.barIcons)
                NumberRow(title: "Height", key: "bar:height", range: 20...50, model: model, fallback: d.barHeight)
                NumberRow(title: "Font size", key: "bar:font_size", range: 9...20, model: model, fallback: d.barFontSize)
                LabeledContent("Font") {
                    TextField("system", text: Binding(get: { model.string("bar:font") ?? "" }, set: {
                        $0.isEmpty ? model.remove("bar:font") : model.set("bar:font", $0)
                    }))
                }
                NumberRow(title: "Space above", key: "bar:margin_top", range: 0...20, model: model, fallback: d.barMarginTop)
                NumberRow(title: "Space below", key: "bar:margin_bottom", range: 0...20, model: model, fallback: d.barMarginBottom)
                OptionalNumberRow(title: "Padding", key: "bar:padding", range: 0...40, model: model,
                                  automatic: model.number("bar:height", d.barHeight) / 2)
                OptionalNumberRow(title: "Rounding", key: "bar:rounding", range: 0...30, model: model,
                                  automatic: model.number("bar:height", d.barHeight) / 2)
                IslandOpacityRow(model: model)
                ColorRow(title: "Tint", key: "bar:col.background", model: model, fallback: d.barBackground)
                ColorRow(title: "Current workspace", key: "bar:col.active", model: model, fallback: d.barActive)
                ColorRow(title: "Workspace on the other screen", key: "bar:col.other_monitor", model: model, fallback: d.barOtherMonitor)
                ColorRow(title: "Text", key: "bar:col.text", model: model, fallback: d.barText)
                ColorRow(title: "Text on the current workspace", key: "bar:col.text_active", model: model, fallback: d.barTextActive)
                ColorRow(title: "Empty workspace text", key: "bar:col.text_empty", model: model, fallback: d.barTextEmpty)
                ColorRow(title: "Error", key: "bar:col.error", model: model, fallback: d.barError)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct IslandOpacityRow: View {
    let model: SettingsModel

    var body: some View {
        let key = "bar:col.background"
        let tint = model.color(key, model.defaults.barBackground)
        LabeledContent("Island opacity") {
            HStack {
                Text("Glass").foregroundStyle(.secondary)
                Slider(value: Binding(get: { tint.a * 100 }, set: {
                    var c = tint
                    c.a = ($0 / 100 * 255).rounded() / 255
                    model.set(key, color: c)
                }), in: 0...100)
                Text("Solid").foregroundStyle(.secondary)
            }
        }
    }
}

private struct BehaviorTab: View {
    let model: SettingsModel

    var body: some View {
        let d = model.defaults
        Form {
            Section {
                FlagRow(title: "Focus follows the mouse", key: "input:follow_mouse", model: model, fallback: d.followMouse)
                FlagRow(title: "Move the cursor to the other screen with focus", key: "cursor:warp_to_monitor", model: model,
                        fallback: d.warpCursor)
                FlagRow(title: "Animations", key: "animations:enabled", model: model, fallback: d.animationsEnabled)
                Toggle("Launch at login", isOn: Binding(get: model.launchAtLogin, set: model.setLaunchAtLogin))
            }
            Section("Config file") {
                Button("Open bento.conf") { model.openFile() }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct ClipboardTab: View {
    let model: SettingsModel

    var body: some View {
        let d = model.defaults
        let shortcut = model.binds.first { $0.dispatcher == "clipboard" }
        Form {
            Section("Clipboard history") {
                LabeledContent("Entries to keep") {
                    HStack {
                        TextField("", value: Binding(
                            get: { Int(model.number("clipboard:history_size", Double(d.clipboardHistorySize))) },
                            set: { model.set("clipboard:history_size", number: Double(min(max($0, 10), 2000))) }),
                                  format: .number)
                            .frame(width: 70)
                        Text("10–2000, pinned entries don't count").foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Open history") {
                    Text(shortcut.map { describe($0, mod: model.mod) } ?? "No shortcut — add one in Shortcuts")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Keep Awake") {
                FlagRow(title: "Turn on Keep Awake when bento starts", key: "clipboard:keep_awake_on_launch", model: model,
                        fallback: d.keepAwakeOnLaunch)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

let dispatchers = [
    "movefocus", "movewindow", "workspace", "movetoworkspace", "movecurrentworkspacetomonitor", "resizeactive",
    "togglesplit", "fullscreen", "togglefloating", "killactive", "exec", "focusorlaunch", "overview", "clipboard",
]

private let modifierNames: [(name: String, symbol: String, flag: NSEvent.ModifierFlags)] = [
    ("CTRL", "⌃", .control), ("ALT", "⌥", .option), ("SHIFT", "⇧", .shift), ("SUPER", "⌘", .command),
]

private let keyNames: [CGKeyCode: String] = {
    let letters = (UnicodeScalar("a").value...UnicodeScalar("z").value).compactMap(UnicodeScalar.init).map(String.init)
    let names = letters + (0...9).map(String.init) + (1...12).map { "f\($0)" } + [
        "return", "tab", "space", "minus", "equal", "left", "right", "up", "down", "escape", "backspace", "mission_control",
    ]
    return Dictionary(names.compactMap { name in keyCode(for: name).map { ($0, name) } }) { first, _ in first }
}()

private let keySymbols = [
    "left": "←", "right": "→", "up": "↑", "down": "↓", "return": "↩", "tab": "⇥", "space": "Space", "escape": "⎋",
    "backspace": "⌫", "minus": "-", "equal": "=", "mission_control": "F3",
]

private func modifierSymbols(_ mods: String, mod: String) -> String {
    let names = Set(mods.replacingOccurrences(of: "$mod", with: mod).uppercased().split(whereSeparator: \.isWhitespace)
        .map { $0 == "CMD" ? "SUPER" : String($0) })
    return modifierNames.filter { names.contains($0.name) }.map(\.symbol).joined()
}

func describe(_ bind: EditableBind, mod: String) -> String {
    modifierSymbols(bind.mods, mod: mod) + (keySymbols[bind.key] ?? bind.key.uppercased())
}

private struct ShortcutsTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section("Modifier ($mod)") {
                HStack {
                    ForEach(modifierNames, id: \.name) { m in
                        Toggle("\(m.symbol) \(m.name.capitalized)", isOn: Binding(
                            get: { modNames.contains(m.name) },
                            set: { on in
                                var names = modNames
                                if on { names.insert(m.name) } else { names.remove(m.name) }
                                model.setMod(modifierNames.map(\.name).filter(names.contains).joined(separator: " "))
                            }))
                            .toggleStyle(.checkbox)
                    }
                }
            }
            Section {
                ForEach(model.binds) { bind in
                    BindRow(model: model, bind: bind)
                }
                Button("Add shortcut") {
                    model.addBind(EditableBind(mods: "$mod", key: "b", dispatcher: "focusorlaunch", args: "Safari"))
                }
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Click a shortcut, then press the new keys. Esc cancels.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var modNames: Set<String> {
        Set(model.mod.uppercased().split(whereSeparator: \.isWhitespace).map { $0 == "CMD" ? "SUPER" : String($0) })
    }
}

private struct BindRow: View {
    let model: SettingsModel
    let bind: EditableBind
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(recording ? "Press keys…" : describe(bind, mod: model.mod)) { startRecording() }
                .frame(width: 110)
            Picker("", selection: Binding(get: { bind.dispatcher }, set: { update { $0.dispatcher = $1 }($0) })) {
                ForEach(dispatchers.contains(bind.dispatcher) ? dispatchers : dispatchers + [bind.dispatcher], id: \.self) {
                    Text($0).tag($0)
                }
            }
            .labelsHidden()
            .frame(width: 210)
            TextField("argument", text: Binding(get: { bind.args }, set: { update { $0.args = $1 }($0) }))
            Button {
                model.removeBind(bind)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .onDisappear(perform: stopRecording)
    }

    private func update(_ change: @escaping (inout EditableBind, String) -> Void) -> (String) -> Void {
        { value in
            var b = bind
            change(&b, value)
            model.setBind(b)
        }
    }

    private func startRecording() {
        guard !recording else { return }
        recording = true
        model.recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
            let code = event.keyCode
            MainActor.assumeIsolated { record(flags, code) }
            return nil
        }
    }

    private func record(_ flags: NSEvent.ModifierFlags, _ code: UInt16) {
        defer { stopRecording() }
        guard code != 53 || !flags.isEmpty, let name = keyNames[CGKeyCode(code)] else { return }
        let pressed = Set(modifierNames.filter { flags.contains($0.flag) }.map(\.name))
        let modSet = Set(model.mod.uppercased().split(whereSeparator: \.isWhitespace).map { $0 == "CMD" ? "SUPER" : String($0) })
        let mods: String
        if !modSet.isEmpty, modSet.isSubset(of: pressed) {
            mods = (["$mod"] + modifierNames.map(\.name).filter { pressed.subtracting(modSet).contains($0) }).joined(separator: " ")
        } else {
            mods = modifierNames.map(\.name).filter(pressed.contains).joined(separator: " ")
        }
        var b = bind
        b.mods = mods
        b.key = name
        model.setBind(b)
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { model.recording = false }
        recording = false
    }
}

private extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: c.alphaComponent)
    }
}
