public func parseConfig(_ text: String) throws(ConfigError) -> Config {
    try buildConfig(parseConfigEntries(text))
}

public func buildConfig(_ entries: [ConfigEntry]) throws(ConfigError) -> Config {
    var config = Config()
    for entry in entries {
        try apply(entry, to: &config)
    }
    return config
}

private func apply(_ entry: ConfigEntry, to config: inout Config) throws(ConfigError) {
    let line = entry.line
    let value = entry.value
    switch entry.key {
    case "general:gaps_in": config.gapsIn = try number(value, line)
    case "general:gaps_out": config.gapsOut = try insets(value, line)
    case "general:border_size": config.borderSize = try number(value, line)
    case "general:border_size_inactive": config.borderSizeInactive = try number(value, line)
    case "general:col.active_border": config.activeBorder = try gradient(value, line)
    case "general:col.inactive_border": config.inactiveBorder = try gradient(value, line)
    case "decoration:rounding": config.rounding = try number(value, line)
    case "bar:enabled": config.barEnabled = try flag(value, line)
    case "clipboard:history_size": config.clipboardHistorySize = Int(min(max(try number(value, line), 10), 2000))
    case "clipboard:keep_awake_on_launch": config.keepAwakeOnLaunch = try flag(value, line)
    case "bar:icons": config.barIcons = try flag(value, line)
    case "bar:height": config.barHeight = try number(value, line)
    case "bar:font_size": config.barFontSize = try number(value, line)
    case "bar:font": config.barFont = value
    case "bar:margin_top": config.barMarginTop = try number(value, line)
    case "bar:margin_bottom": config.barMarginBottom = try number(value, line)
    case "bar:padding": config.barPadding = try number(value, line)
    case "bar:rounding": config.barRounding = try number(value, line)
    case "bar:col.background": config.barBackground = try color(value, line)
    case "bar:col.active": config.barActive = try color(value, line)
    case "bar:col.other_monitor": config.barOtherMonitor = try color(value, line)
    case "bar:col.text": config.barText = try color(value, line)
    case "bar:col.text_active": config.barTextActive = try color(value, line)
    case "bar:col.text_empty": config.barTextEmpty = try color(value, line)
    case "bar:col.error": config.barError = try color(value, line)
    case "input:follow_mouse": config.followMouse = try flag(value, line)
    case "cursor:warp_to_monitor": config.warpCursor = try flag(value, line)
    case "animations:enabled": config.animationsEnabled = try flag(value, line)
    case "animations:bezier": try applyBezier(value, line, to: &config)
    case "animations:animation": try applyAnimation(value, line, to: &config)
    case "workspace": try applyWorkspace(value, line, to: &config)
    case "bind": try applyBind(value, line, to: &config)
    case "bindm": try applyMouseBind(value, line, to: &config)
    case "windowrule": try applyWindowRule(value, line, to: &config)
    default: throw ConfigError(line: line, message: "unknown option '\(entry.key)'")
    }
}

private func applyBezier(_ value: String, _ line: Int, to config: inout Config) throws(ConfigError) {
    let parts = commaSeparated(value)
    guard parts.count == 5, !parts[0].isEmpty else {
        throw ConfigError(line: line, message: "bezier needs 'name, x1, y1, x2, y2'")
    }
    config.beziers[parts[0]] = CubicBezierSpec(
        x1: try number(parts[1], line),
        y1: try number(parts[2], line),
        x2: try number(parts[3], line),
        y2: try number(parts[4], line)
    )
}

private func applyAnimation(_ value: String, _ line: Int, to config: inout Config) throws(ConfigError) {
    let parts = commaSeparated(value)
    guard parts.count == 4 || parts.count == 5 else {
        throw ConfigError(line: line, message: "animation needs 'name, 0|1, speed, curve[, style]'")
    }
    guard config.animations[parts[0]] != nil else {
        throw ConfigError(line: line, message: "unknown animation '\(parts[0])'")
    }
    guard config.beziers[parts[3]] != nil else {
        throw ConfigError(line: line, message: "unknown bezier '\(parts[3])'")
    }
    config.animations[parts[0]] = AnimationSpec(
        enabled: try flag(parts[1], line),
        duration: try number(parts[2], line) / 10,
        curve: parts[3],
        style: parts.count == 5 ? parts[4] : nil
    )
}

private func applyWorkspace(_ value: String, _ line: Int, to config: inout Config) throws(ConfigError) {
    let parts = commaSeparated(value)
    guard parts.count == 3, parts[1].hasPrefix("monitor:"), parts[2] == "default:true" else {
        throw ConfigError(line: line, message: "workspace needs 'N, monitor:builtin|external, default:true'")
    }
    let monitor = String(parts[1].dropFirst("monitor:".count))
    guard let selector = MonitorSelector(rawValue: monitor) else {
        throw ConfigError(line: line, message: "unknown monitor '\(monitor)'")
    }
    config.startupWorkspace[selector] = try workspaceNumber(parts[0], line)
}

private func applyBind(_ value: String, _ line: Int, to config: inout Config) throws(ConfigError) {
    let parts = commaSeparated(value, maxSplits: 3)
    guard parts.count >= 3 else {
        throw ConfigError(line: line, message: "bind needs 'MODS, key, dispatcher[, arg]'")
    }
    let key = parts[1].lowercased()
    guard !key.isEmpty else { throw ConfigError(line: line, message: "bind needs a key") }
    config.keyBinds.append(KeyBind(
        mods: try modifiers(parts[0], line),
        key: key,
        action: try action(dispatcher: parts[2], argument: parts.count > 3 ? parts[3] : "", line)
    ))
}

private func applyMouseBind(_ value: String, _ line: Int, to config: inout Config) throws(ConfigError) {
    let parts = commaSeparated(value)
    guard parts.count == 3 else {
        throw ConfigError(line: line, message: "bindm needs 'MODS, mouse:N, dispatcher'")
    }
    guard parts[1].hasPrefix("mouse:"), let button = Int(parts[1].dropFirst("mouse:".count)) else {
        throw ConfigError(line: line, message: "invalid mouse button '\(parts[1])'")
    }
    let mouseAction: MouseAction
    switch parts[2] {
    case "movewindow": mouseAction = .move
    case "resizewindow": mouseAction = .resize
    default: throw ConfigError(line: line, message: "unknown dispatcher '\(parts[2])'")
    }
    config.mouseBinds.append(MouseBind(mods: try modifiers(parts[0], line), button: button, action: mouseAction))
}

private func applyWindowRule(_ value: String, _ line: Int, to config: inout Config) throws(ConfigError) {
    let parts = commaSeparated(value)
    guard parts[0] == "float" else {
        throw ConfigError(line: line, message: "unknown window rule '\(parts[0])'")
    }
    var rule = WindowRule()
    for field in parts.dropFirst() {
        if field.hasPrefix("app:") {
            rule.appPattern = try pattern(String(field.dropFirst("app:".count)), line)
        } else if field.hasPrefix("title:") {
            rule.titlePattern = try pattern(String(field.dropFirst("title:".count)), line)
        } else {
            throw ConfigError(line: line, message: "unknown window rule field '\(field)'")
        }
    }
    guard rule.appPattern != nil || rule.titlePattern != nil else {
        throw ConfigError(line: line, message: "windowrule needs app: or title:")
    }
    config.floatRules.append(rule)
}

private func action(dispatcher: String, argument: String, _ line: Int) throws(ConfigError) -> Action {
    switch dispatcher {
    case "exec":
        guard !argument.isEmpty else { throw ConfigError(line: line, message: "exec needs a command") }
        return .exec(argument)
    case "focusorlaunch":
        guard !argument.isEmpty else { throw ConfigError(line: line, message: "focusorlaunch needs an app name") }
        return .focusOrLaunch(argument)
    case "movefocus": return .moveFocus(try direction(argument, line))
    case "movewindow": return .moveWindow(try direction(argument, line))
    case "workspace": return .workspace(try workspaceNumber(argument, line))
    case "movetoworkspace": return .moveToWorkspace(try workspaceNumber(argument, line))
    case "movecurrentworkspacetomonitor": return .moveCurrentWorkspaceToMonitor
    case "resizeactive":
        let deltas = argument.split(whereSeparator: \.isWhitespace)
        guard deltas.count == 2 else { throw ConfigError(line: line, message: "resizeactive needs 'DX DY'") }
        return .resizeActive(dx: try number(String(deltas[0]), line), dy: try number(String(deltas[1]), line))
    case "togglesplit": return .toggleSplit
    case "fullscreen": return .fullscreen
    case "togglefloating": return .toggleFloating
    case "killactive": return .killActive
    case "overview": return .overview
    case "clipboard": return .clipboard
    case "palette": return .palette
    default: throw ConfigError(line: line, message: "unknown dispatcher '\(dispatcher)'")
    }
}

private func direction(_ text: String, _ line: Int) throws(ConfigError) -> Direction {
    guard let direction = Direction(rawValue: text) else {
        throw ConfigError(line: line, message: "invalid direction '\(text)'")
    }
    return direction
}

private func workspaceNumber(_ text: String, _ line: Int) throws(ConfigError) -> Int {
    guard let number = Int(text), (0...9).contains(number) else {
        throw ConfigError(line: line, message: "workspace must be 0-9")
    }
    return number
}

private func modifiers(_ text: String, _ line: Int) throws(ConfigError) -> Modifiers {
    var result: Modifiers = []
    for token in text.split(separator: " ") {
        switch token.lowercased() {
        case "ctrl", "control": result.insert(.ctrl)
        case "alt", "option": result.insert(.alt)
        case "shift": result.insert(.shift)
        case "cmd", "super": result.insert(.cmd)
        default: throw ConfigError(line: line, message: "unknown modifier '\(token)'")
        }
    }
    return result
}

private func number(_ text: String, _ line: Int) throws(ConfigError) -> Double {
    guard let number = Double(text) else { throw ConfigError(line: line, message: "invalid number '\(text)'") }
    return number
}

private func insets(_ text: String, _ line: Int) throws(ConfigError) -> Insets {
    var values: [Double] = []
    for token in text.split(whereSeparator: { $0 == "," || $0.isWhitespace }) {
        values.append(try number(String(token), line))
    }
    switch values.count {
    case 1: return Insets(all: values[0])
    case 2: return Insets(top: values[0], right: values[1], bottom: values[0], left: values[1])
    case 3: return Insets(top: values[0], right: values[1], bottom: values[2], left: values[1])
    case 4: return Insets(top: values[0], right: values[1], bottom: values[2], left: values[3])
    default: throw ConfigError(line: line, message: "gaps_out needs 1-4 numbers")
    }
}

private func flag(_ text: String, _ line: Int) throws(ConfigError) -> Bool {
    switch text {
    case "true", "1": return true
    case "false", "0": return false
    default: throw ConfigError(line: line, message: "invalid flag '\(text)'")
    }
}

private func gradient(_ text: String, _ line: Int) throws(ConfigError) -> Gradient {
    var tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
    var angle = 0.0
    if let last = tokens.last, last.hasSuffix("deg") {
        guard let degrees = Double(last.dropLast("deg".count)) else {
            throw ConfigError(line: line, message: "invalid color '\(last)'")
        }
        angle = degrees
        tokens.removeLast()
    }
    guard !tokens.isEmpty else { throw ConfigError(line: line, message: "invalid color '\(text)'") }
    var colors: [RGBA] = []
    for token in tokens {
        colors.append(try color(token, line))
    }
    return Gradient(colors: colors, angleDegrees: angle)
}

private func color(_ token: String, _ line: Int) throws(ConfigError) -> RGBA {
    let lowered = token.lowercased()
    guard lowered.hasSuffix(")") else { throw ConfigError(line: line, message: "invalid color '\(token)'") }
    let digits: String
    let alphaShift: UInt32
    if lowered.hasPrefix("rgba(") {
        digits = String(lowered.dropFirst("rgba(".count).dropLast())
        alphaShift = 0
    } else if lowered.hasPrefix("rgb(") {
        digits = String(lowered.dropFirst("rgb(".count).dropLast())
        alphaShift = 8
    } else {
        throw ConfigError(line: line, message: "invalid color '\(token)'")
    }
    guard digits.count == (alphaShift == 0 ? 8 : 6), digits.allSatisfy(\.isHexDigit), let hex = UInt32(digits, radix: 16) else {
        throw ConfigError(line: line, message: "invalid color '\(token)'")
    }
    return RGBA(hex: alphaShift == 0 ? hex : hex << 8 | 0xff)
}

private func pattern(_ text: String, _ line: Int) throws(ConfigError) -> String {
    do {
        _ = try Regex(text)
    } catch {
        throw ConfigError(line: line, message: "invalid regex '\(text)'")
    }
    return text
}

private func commaSeparated(_ text: String, maxSplits: Int = .max) -> [String] {
    text.split(separator: ",", maxSplits: maxSplits, omittingEmptySubsequences: false).map { piece in
        var slice = piece
        while slice.first?.isWhitespace == true { slice.removeFirst() }
        while slice.last?.isWhitespace == true { slice.removeLast() }
        return String(slice)
    }
}

public func parseColor(_ text: String) -> RGBA? {
    try? color(text, 0)
}

public func parseGradient(_ text: String) -> Gradient? {
    try? gradient(text, 0)
}

public func parseInsets(_ text: String) -> Insets? {
    try? insets(text, 0)
}
