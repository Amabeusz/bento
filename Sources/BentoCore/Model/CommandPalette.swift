public enum AppCommand: String, Sendable, CaseIterable {
    case settings, togglePause, keepAwake, launchAtLogin, clearClipboard, quit
}

public enum PaletteTarget: Equatable, Sendable {
    case action(Action)
    case app(AppCommand)
}

public struct PaletteCommand: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let symbol: String
    public var shortcut: String?
    public let target: PaletteTarget

    public init(id: String, title: String, symbol: String, shortcut: String? = nil, target: PaletteTarget) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self.target = target
    }
}

private let directions: [(Direction, String)] = [(.left, "left"), (.right, "right"), (.up, "up"), (.down, "down")]

public func paletteCommands(binds: [KeyBind]) -> [PaletteCommand] {
    func act(_ id: String, _ title: String, _ symbol: String, _ action: Action) -> PaletteCommand {
        PaletteCommand(id: id, title: title, symbol: symbol, target: .action(action))
    }
    var list: [PaletteCommand] = []
    list += (0...9).map { act("workspace:\($0)", "Go to workspace \($0)", "\($0).square", .workspace($0)) }
    list += (0...9).map { act("movetoworkspace:\($0)", "Move window to workspace \($0)", "arrow.right.square", .moveToWorkspace($0)) }
    list += directions.map { act("movefocus:\($0.0.rawValue)", "Focus \($0.1)", "arrow.\($0.1).circle", .moveFocus($0.0)) }
    list += directions.map { act("movewindow:\($0.0.rawValue)", "Move window \($0.1)", "arrow.\($0.1).square", .moveWindow($0.0)) }
    list += [
        act("movecurrentworkspacetomonitor", "Move workspace to other monitor", "display.2", .moveCurrentWorkspaceToMonitor),
        act("togglesplit", "Toggle split", "rectangle.split.2x1", .toggleSplit),
        act("fullscreen", "Toggle fullscreen", "arrow.up.left.and.arrow.down.right", .fullscreen),
        act("togglefloating", "Toggle floating", "macwindow.on.rectangle", .toggleFloating),
        act("killactive", "Close window", "xmark.square", .killActive),
        act("grow", "Grow window", "plus.square", .resizeActive(dx: 50, dy: 50)),
        act("shrink", "Shrink window", "minus.square", .resizeActive(dx: -50, dy: -50)),
        act("overview", "Window overview", "square.grid.3x3", .overview),
        act("clipboard", "Clipboard history", "doc.on.clipboard", .clipboard),
        act("terminal", "Open terminal", "terminal", .terminal),
    ]
    for bind in binds {
        switch bind.action {
        case .exec(let command): list.append(act("exec:\(command)", "Run: \(command)", "terminal", bind.action))
        case .focusOrLaunch(let app): list.append(act("focusorlaunch:\(app)", "Open \(app)", "app", bind.action))
        default: break
        }
    }
    list += [
        PaletteCommand(id: "app:settings", title: "Settings…", symbol: "gearshape", target: .app(.settings)),
        PaletteCommand(id: "app:togglePause", title: "Pause tiling", symbol: "pause.circle", target: .app(.togglePause)),
        PaletteCommand(id: "app:keepAwake", title: "Keep Awake", symbol: "cup.and.saucer", target: .app(.keepAwake)),
        PaletteCommand(id: "app:launchAtLogin", title: "Launch at login", symbol: "power", target: .app(.launchAtLogin)),
        PaletteCommand(id: "app:clearClipboard", title: "Clear clipboard history", symbol: "clipboard", target: .app(.clearClipboard)),
        PaletteCommand(id: "app:quit", title: "Quit Bento", symbol: "xmark.circle", target: .app(.quit)),
    ]
    var seen: Set<String> = []
    list = list.filter { seen.insert($0.id).inserted }
    for i in list.indices {
        guard case .action(let action) = list[i].target else { continue }
        list[i].shortcut = binds.first { $0.action == action }.map(shortcutLabel)
    }
    return list
}

private let keySymbols = [
    "left": "←", "right": "→", "up": "↑", "down": "↓", "return": "↩", "tab": "⇥", "space": "Space", "escape": "⎋",
    "backspace": "⌫", "minus": "-", "equal": "=", "mission_control": "F3",
]

public func shortcutLabel(_ bind: KeyBind) -> String {
    let mods = [(Modifiers.ctrl, "⌃"), (.alt, "⌥"), (.shift, "⇧"), (.cmd, "⌘")]
        .filter { bind.mods.contains($0.0) }.map(\.1).joined()
    return mods + (keySymbols[bind.key] ?? bind.key.uppercased())
}

public func rankCommands(_ all: [PaletteCommand], query: String, recent: [String]) -> [PaletteCommand] {
    let recentRank = Dictionary(recent.prefix(5).enumerated().map { ($1, $0) }) { first, _ in first }
    let q = Array(query.lowercased())
    let scored = all.enumerated().compactMap { index, command -> (PaletteCommand, Int, Int, Int)? in
        guard let score = q.isEmpty ? 0 : matchScore(q, Array(command.title.lowercased())) else { return nil }
        return (command, score, recentRank[command.id] ?? Int.max, index)
    }
    return scored.sorted { a, b in
        if a.1 != b.1 { return a.1 > b.1 }
        if a.2 != b.2 { return a.2 < b.2 }
        return a.3 < b.3
    }.map(\.0)
}

private func matchScore(_ query: [Character], _ title: [Character]) -> Int? {
    [true, false].compactMap { score(query, title, preferWordStarts: $0) }.max()
}

private func score(_ query: [Character], _ title: [Character], preferWordStarts: Bool) -> Int? {
    func isWordStart(_ i: Int) -> Bool { i == 0 || title[i - 1] == " " }
    var position = 0
    var previous = -2
    var total = 0
    for q in query {
        let candidates = (position..<title.count).filter { title[$0] == q }
        guard let first = candidates.first else { return nil }
        let wordStart = candidates.first(where: isWordStart)
        let i = first == previous + 1 || !preferWordStarts ? first : wordStart ?? first
        total += 1 + (i == previous + 1 ? 3 : 0) + (isWordStart(i) ? 5 : 0)
        previous = i
        position = i + 1
    }
    return total
}
