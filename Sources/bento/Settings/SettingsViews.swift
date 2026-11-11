import AppKit
import BentoCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { item in
                    Button { model.tab = item } label: {
                        VStack(spacing: 3) {
                            Image(systemName: item.symbol).font(.system(size: 17)).frame(height: 20)
                            Text(item.rawValue).font(.caption)
                        }
                        .frame(width: 80, height: 46)
                        .foregroundStyle(model.tab == item ? Color.accentColor : .secondary)
                        .background(model.tab == item ? Color.primary.opacity(0.08) : .clear, in: .rect(cornerRadius: 8))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                }
            }
            .padding(.top, 4)
            if let error = model.saveError ?? model.configError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            switch model.tab {
            case .appearance: AppearanceTab(model: model)
            case .behavior: BehaviorTab(model: model)
            case .shortcuts: ShortcutsTab(model: model)
            case .clipboard: ClipboardTab(model: model)
            case .permissions: PermissionsTab(model: model)
            case .about: AboutTab()
            }
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}

enum SettingsTab: String, CaseIterable {
    case appearance = "Appearance", behavior = "Behavior", shortcuts = "Shortcuts", clipboard = "Clipboard"
    case permissions = "Permissions", about = "About"

    var symbol: String {
        switch self {
        case .appearance: "paintbrush"
        case .behavior: "gearshape.2"
        case .shortcuts: "keyboard"
        case .clipboard: "clipboard"
        case .permissions: "lock.shield"
        case .about: "info.circle"
        }
    }
}

private struct PermissionsTab: View {
    let model: SettingsModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Form {
                ForEach(Permission.allCases, id: \.self) { permission in
                    PermissionSection(permission: permission, granted: model.permissionGranted(permission), model: model)
                }
                Section("Works without permissions") {
                    Text(Feature.allCases.filter { $0.permission == nil }.map(\.rawValue).joined(separator: ", "))
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct PermissionSection: View {
    let permission: Permission
    let granted: Bool
    let model: SettingsModel

    var body: some View {
        Section {
            Text(purpose).foregroundStyle(.secondary)
            HStack {
                if !granted { Text(afterGranting).foregroundStyle(.secondary) }
                Spacer()
                Button("Open System Settings") { model.openSystemSettings(for: permission) }
            }
        } header: {
            HStack {
                Text(permission.rawValue)
                Spacer()
                Label(granted ? "Granted" : "Not granted",
                      systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? .green : .orange)
            }
        }
    }

    private var purpose: String {
        switch permission {
        case .accessibility: "Lets bento move and resize windows of other apps and react to its shortcuts."
        case .screenRecording: "Lets bento take pictures of windows for animations and overview thumbnails."
        }
    }

    private var afterGranting: String {
        switch permission {
        case .accessibility: "Tiling starts on its own once granted."
        case .screenRecording: "Restart bento after granting it."
        }
    }
}

private struct AboutTab: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text("bento").font(.title.bold())
            Text("Tiling window manager for macOS").foregroundStyle(.secondary)
            if let version {
                Text("Version \(version)").font(.caption).foregroundStyle(.tertiary)
            }
            Link(destination: URL(string: "https://github.com/Amabeusz/bento")!) {
                Label("github.com/Amabeusz/bento", systemImage: "arrow.up.right.square")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        LabeledContent(title) {
            HStack {
                ColorPicker(title, selection: Binding(
                    get: { model.color(key, fallback).color },
                    set: { model.set(key, color: RGBA($0)) }), supportsOpacity: true)
                    .labelsHidden()
                ResetButton(isDefault: colorIsDefault(model.string(key), fallback)) { model.set(key, color: fallback) }
            }
        }
    }
}

private struct ResetButton: View {
    let isDefault: Bool
    let reset: () -> Void

    var body: some View {
        Button(action: reset) { Image(systemName: "arrow.counterclockwise") }
            .help("Reset to default")
            .disabled(isDefault)
    }
}

private struct BorderColorRow: View {
    let title: String
    let key: String
    let model: SettingsModel
    let fallback: BentoCore.Gradient

    var body: some View {
        if let gradient = model.gradient(key, fallback) {
            LabeledContent(title) {
                VStack(alignment: .trailing) {
                    HStack {
                        ForEach(gradient.colors.indices, id: \.self) { i in
                            ColorPicker(title, selection: Binding(
                                get: { gradient.colors[i].color },
                                set: { color in edit { $0.colors[i] = RGBA(color) } }), supportsOpacity: true)
                                .labelsHidden()
                        }
                        Button { edit { $0.colors.removeLast() } } label: { Image(systemName: "minus") }
                            .disabled(gradient.colors.count < 2)
                        Button { edit { $0.colors.append($0.colors[$0.colors.count - 1]) } } label: { Image(systemName: "plus") }
                        ResetButton(isDefault: gradient == fallback) { model.set(key, gradient: fallback) }
                    }
                    if gradient.colors.count > 1 {
                        HStack {
                            Slider(value: Binding(get: { gradient.angleDegrees },
                                                  set: { angle in edit { $0.angleDegrees = angle.rounded() } }), in: 0...360)
                            Text("\(Int(gradient.angleDegrees))°").monospacedDigit().frame(width: 36, alignment: .trailing)
                        }
                    }
                }
            }
        } else {
            LabeledContent(title) {
                HStack {
                    TextField(title, text: Binding(get: { model.string(key) ?? "" }, set: { model.set(key, $0) }),
                              prompt: Text("rgba(…) rgba(…) 135deg"))
                        .labelsHidden()
                        .font(.system(.body, design: .monospaced))
                    ResetButton(isDefault: false) { model.set(key, gradient: fallback) }
                }
            }
        }
    }

    private func edit(_ change: (inout BentoCore.Gradient) -> Void) {
        guard var gradient = model.gradient(key, fallback) else { return }
        change(&gradient)
        model.set(key, gradient: gradient)
    }
}

private struct EdgeGapsRow: View {
    let model: SettingsModel
    let fallback: Insets
    private let key = "general:gaps_out"
    private let range = 0.0...60

    var body: some View {
        if let insets = model.insets(key, fallback) {
            let perSide = (model.string(key) ?? "").split(whereSeparator: { $0 == "," || $0.isWhitespace }).count > 1
            LabeledContent("Gap to screen edges") {
                HStack {
                    Toggle("Per side", isOn: Binding(get: { perSide }, set: { model.set(key, insets: insets, perSide: $0) }))
                        .toggleStyle(.checkbox)
                    if !perSide {
                        slider(insets.top) { Insets(all: $0) }
                    }
                }
            }
            if perSide {
                LabeledContent("Top") { slider(insets.top) { var i = insets; i.top = $0; return i } }
                LabeledContent("Right") { slider(insets.right) { var i = insets; i.right = $0; return i } }
                LabeledContent("Bottom") { slider(insets.bottom) { var i = insets; i.bottom = $0; return i } }
                LabeledContent("Left") { slider(insets.left) { var i = insets; i.left = $0; return i } }
            }
        } else {
            LabeledContent("Gap to screen edges") {
                TextField("Gap to screen edges", text: Binding(get: { model.string(key) ?? "" }, set: { model.set(key, $0) }),
                          prompt: Text("12 or top right bottom left"))
                    .labelsHidden()
            }
        }
    }

    private func slider(_ value: Double, _ apply: @escaping (Double) -> Insets) -> some View {
        let perSide = (model.string(key) ?? "").split(whereSeparator: { $0 == "," || $0.isWhitespace }).count > 1
        return HStack {
            Slider(value: Binding(get: { value }, set: { model.set(key, insets: apply($0.rounded()), perSide: perSide) }),
                   in: range, step: 1)
            Text("\(Int(value))").monospacedDigit().frame(width: 36, alignment: .trailing)
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
                EdgeGapsRow(model: model, fallback: d.gapsOut)
                NumberRow(title: "Border", key: "general:border_size", range: 0...10, model: model, fallback: d.borderSize)
                OptionalNumberRow(title: "Border of unfocused windows", key: "general:border_size_inactive", range: 0...10,
                                  model: model, automatic: model.number("general:border_size", d.borderSize))
                BorderColorRow(title: "Focused border color", key: "general:col.active_border", model: model,
                               fallback: d.activeBorder)
                BorderColorRow(title: "Unfocused border color", key: "general:col.inactive_border", model: model,
                               fallback: d.inactiveBorder)
            }
            Section("Island") {
                FlagRow(title: "Show the island", key: "bar:enabled", model: model, fallback: d.barEnabled)
                FlagRow(title: "App icons next to workspace numbers", key: "bar:icons", model: model, fallback: d.barIcons)
                NumberRow(title: "Height", key: "bar:height", range: 20...50, model: model, fallback: d.barHeight)
                NumberRow(title: "Font size", key: "bar:font_size", range: 9...20, model: model, fallback: d.barFontSize)
                LabeledContent("Font") {
                    TextField("Font", text: Binding(get: { model.string("bar:font") ?? "" }, set: {
                        $0.isEmpty ? model.remove("bar:font") : model.set("bar:font", $0)
                    }), prompt: Text("system"))
                        .labelsHidden()
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

let modifierNames: [(name: String, symbol: String, flag: NSEvent.ModifierFlags)] = [
    ("CTRL", "⌃", .control), ("ALT", "⌥", .option), ("SHIFT", "⇧", .shift), ("SUPER", "⌘", .command),
]

let keyNames: [CGKeyCode: String] = {
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

private extension RGBA {
    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(r: c.redComponent, g: c.greenComponent, b: c.blueComponent, a: c.alphaComponent)
    }
}
