import Testing
@testable import BentoCore

@Test func defaultConfigParses() throws {
    let c = try parseConfig(defaultConfigText)
    #expect(c.gapsIn == 10 && c.gapsOut == Insets(all: 12) && c.borderSize == 2 && c.rounding == 16)
    #expect(c.activeBorder == Gradient(colors: [RGBA(hex: 0xf5c2e7ff), RGBA(hex: 0xcba6f7ff), RGBA(hex: 0x89b4faff)], angleDegrees: 135))
    #expect(c.keyBinds.contains(KeyBind(mods: [.ctrl, .alt], key: "0", action: .workspace(0))))
    #expect(c.keyBinds.contains(KeyBind(mods: [.ctrl, .alt, .shift], key: "tab", action: .moveCurrentWorkspaceToMonitor)))
    #expect(c.keyBinds.contains(KeyBind(mods: [.ctrl, .alt], key: "minus", action: .resizeActive(dx: -50, dy: -50))))
    #expect(c.mouseBinds == [MouseBind(mods: [.ctrl, .alt], button: 272, action: .move), MouseBind(mods: [.ctrl, .alt], button: 273, action: .resize)])
    #expect(c.animations["workspaces"] == AnimationSpec(enabled: true, duration: 0.3, curve: "smooth", style: "slide"))
    #expect(c.startupWorkspace == [.builtin: 1, .external: 1])
    #expect(c.floatRules.count == 2 && !c.followMouse && c.warpCursor)
}

@Test func swiftDefaultsMirrorDefaultConfigText() throws {
    var expected = try parseConfig(defaultConfigText)
    expected.keyBinds = []
    expected.mouseBinds = []
    expected.floatRules = []
    #expect(Config() == expected)
}

@Test func focusOrLaunchKeepsSpaces() throws {
    #expect(try parseConfig("bind = CTRL, i, focusorlaunch, IntelliJ IDEA").keyBinds[0].action == .focusOrLaunch("IntelliJ IDEA"))
}

@Test func execKeepsCommasInCommand() throws {
    #expect(try parseConfig("bind = CTRL, e, exec, sh -c 'a, b'").keyBinds[0].action == .exec("sh -c 'a, b'"))
}

@Test func modifierAliasesAreCaseInsensitive() throws {
    #expect(try parseConfig("bind = control option super shift, a, killactive").keyBinds[0].mods == [.ctrl, .alt, .cmd, .shift])
}

@Test func unknownModifier() {
    #expect(throws: ConfigError(line: 1, message: "unknown modifier 'HYPER'")) { try parseConfig("bind = HYPER, a, killactive") }
}

@Test func unknownOptionReportsLine() {
    #expect(throws: ConfigError(line: 2, message: "unknown option 'general:gapz_in'")) { try parseConfig("general {\n gapz_in = 3\n}") }
}

@Test func unknownDispatcher() {
    #expect(throws: ConfigError(line: 1, message: "unknown dispatcher 'foo'")) { try parseConfig("bind = CTRL, a, foo") }
}

@Test func workspaceOutOfRange() {
    #expect(throws: ConfigError(line: 1, message: "workspace must be 0-9")) { try parseConfig("bind = CTRL, a, workspace, 11") }
}

@Test func animationReferencesUnknownBezier() {
    #expect(throws: ConfigError(line: 2, message: "unknown bezier 'nope'")) { try parseConfig("animations {\nanimation = windows, 1, 3, nope\n}") }
}

@Test func badColor() {
    #expect(throws: ConfigError(line: 2, message: "invalid color 'red'")) { try parseConfig("general {\ncol.active_border = red\n}") }
}

@Test func rgbColorIsOpaqueAndAngleIsOptional() throws {
    let c = try parseConfig("general {\ncol.inactive_border = rgb(ff0000) rgb(00ff00)\n}")
    #expect(c.inactiveBorder == Gradient(colors: [RGBA(hex: 0xff0000ff), RGBA(hex: 0x00ff00ff)], angleDegrees: 0))
}

@Test func userBezierAddsAndOverrides() throws {
    let c = try parseConfig("animations {\nbezier = mine, 0.1, 0.2, 0.3, 0.4\nbezier = linear, 0, 0, 0.5, 0.5\n}")
    #expect(c.beziers["mine"] == CubicBezierSpec(x1: 0.1, y1: 0.2, x2: 0.3, y2: 0.4))
    #expect(c.beziers["linear"] == CubicBezierSpec(x1: 0, y1: 0, x2: 0.5, y2: 0.5))
    #expect(c.beziers["default"] != nil)
}

@Test func disabledAnimationIsRecorded() throws {
    #expect(try parseConfig("animations {\nanimation = border, 0, 5, default\n}").animations["border"]?.enabled == false)
}

@Test func windowRuleFields() throws {
    let c = try parseConfig("windowrule = float, app:^Finder$, title:Info$")
    #expect(c.floatRules == [WindowRule(appPattern: "^Finder$", titlePattern: "Info$")])
}

@Test func invalidRegex() {
    #expect(throws: ConfigError(line: 1, message: "invalid regex '('")) { try parseConfig("windowrule = float, app:(") }
}

@Test func workspaceLineOverridesStartup() throws {
    #expect(try parseConfig("workspace = 3, monitor:external, default:true").startupWorkspace == [.builtin: 1, .external: 3])
}

@Test func nonNumberReportsLine() {
    #expect(throws: ConfigError(line: 2, message: "invalid number 'x'")) { try parseConfig("general {\n gaps_in = x\n}") }
}

@Test func emptyConfigHasDefaultsAndNoBinds() throws {
    let c = try parseConfig("")
    #expect(c == Config())
    #expect(c.keyBinds.isEmpty)
}

@Test func moveFocusNeedsDirection() {
    #expect(throws: ConfigError(line: 1, message: "invalid direction 'x'")) { try parseConfig("bind = CTRL, a, movefocus, x") }
}

@Test func mouseBinds() throws {
    #expect(try parseConfig("bindm = CTRL, mouse:273, resizewindow").mouseBinds == [MouseBind(mods: [.ctrl], button: 273, action: .resize)])
}

@Test func gapsOutTakesOneToFourValuesLikeCss() throws {
    func gaps(_ value: String) throws -> Insets { try parseConfig("general {\n gaps_out = \(value)\n}").gapsOut }
    #expect(try gaps("12") == Insets(all: 12))
    #expect(try gaps("10 20") == Insets(top: 10, right: 20, bottom: 10, left: 20))
    #expect(try gaps("10 20 30") == Insets(top: 10, right: 20, bottom: 30, left: 20))
    #expect(try gaps("10, 20, 30, 40") == Insets(top: 10, right: 20, bottom: 30, left: 40))
}

@Test func gapsOutRejectsFiveValues() {
    #expect(throws: ConfigError(line: 2, message: "gaps_out needs 1-4 numbers")) { try parseConfig("general {\n gaps_out = 1 2 3 4 5\n}") }
}

@Test func gapsOutRejectsText() {
    #expect(throws: ConfigError(line: 2, message: "invalid number 'x'")) { try parseConfig("general {\n gaps_out = 10 x\n}") }
}

@Test func barAppearanceKeys() throws {
    let c = try parseConfig("""
    bar {
        margin_top = 6
        margin_bottom = 10
        padding = 8
        rounding = 4
        col.background = rgba(11223344)
        col.active = rgb(010203)
        col.other_monitor = rgba(0a0b0c0d)
        col.text = rgba(ffffffff)
        col.text_active = rgba(000000ff)
        col.text_empty = rgba(808080ff)
        col.error = rgba(ff0000ff)
    }
    """)
    #expect(c.barMarginTop == 6 && c.barMarginBottom == 10 && c.barPadding == 8 && c.barRounding == 4)
    #expect(c.barBackground == RGBA(hex: 0x11223344) && c.barActive == RGBA(hex: 0x010203ff))
    #expect(c.barOtherMonitor == RGBA(hex: 0x0a0b0c0d) && c.barText == RGBA(hex: 0xffffffff))
    #expect(c.barTextActive == RGBA(hex: 0x000000ff) && c.barTextEmpty == RGBA(hex: 0x808080ff) && c.barError == RGBA(hex: 0xff0000ff))
}

@Test func barPaddingAndRoundingAreUnsetByDefault() {
    #expect(Config().barPadding == nil && Config().barRounding == nil)
}

@Test func inactiveBorderSizeFallsBackToBorderSize() throws {
    let c = try parseConfig("general {\n border_size = 3\n border_size_inactive = 0\n}")
    #expect(c.borderSize(isFocused: true) == 3 && c.borderSize(isFocused: false) == 0)
    #expect(try parseConfig("general {\n border_size = 3\n}").borderSize(isFocused: false) == 3)
}

@Test func workspaceZeroParsesTenFails() throws {
    #expect(try parseConfig("bind = CTRL, a, workspace, 0").keyBinds[0].action == .workspace(0))
    #expect(try parseConfig("bind = CTRL, a, movetoworkspace, 0").keyBinds[0].action == .moveToWorkspace(0))
    #expect(throws: ConfigError(line: 1, message: "workspace must be 0-9")) { try parseConfig("bind = CTRL, a, workspace, 10") }
}

@Test func barIconsKey() throws {
    #expect(try parseConfig("").barIcons)
    #expect(try !parseConfig("bar {\n    icons = false\n}").barIcons)
}

@Test func overviewDispatcherBindsWithoutModifiers() throws {
    #expect(try parseConfig("bind = , mission_control, overview").keyBinds == [KeyBind(mods: [], key: "mission_control", action: .overview)])
    #expect(try parseConfig(defaultConfigText).keyBinds.contains(KeyBind(mods: [], key: "mission_control", action: .overview)))
    #expect(try parseConfig(defaultConfigText).keyBinds.contains(KeyBind(mods: [.ctrl], key: "up", action: .overview)))
}

@Test func clipboardDispatcherBinds() throws {
    let bind = KeyBind(mods: [.cmd, .shift], key: "c", action: .clipboard)
    #expect(try parseConfig("bind = SUPER SHIFT, c, clipboard").keyBinds == [bind])
    #expect(try parseConfig(defaultConfigText).keyBinds.contains(bind))
}

@Test func clipboardKeys() throws {
    let defaults = try parseConfig("")
    #expect(defaults.clipboardHistorySize == 200)
    #expect(!defaults.keepAwakeOnLaunch)
    let set = try parseConfig("clipboard {\n    history_size = 50\n    keep_awake_on_launch = true\n}")
    #expect(set.clipboardHistorySize == 50)
    #expect(set.keepAwakeOnLaunch)
    #expect(try parseConfig("clipboard {\n    history_size = 5000\n}").clipboardHistorySize == 2000)
    #expect(try parseConfig("clipboard {\n    history_size = 1\n}").clipboardHistorySize == 10)
    #expect(throws: ConfigError(line: 2, message: "invalid number 'many'")) {
        try parseConfig("clipboard {\n    history_size = many\n}")
    }
}

@Test func paletteDispatcherBinds() throws {
    let bind = KeyBind(mods: [.ctrl, .alt], key: "space", action: .palette)
    #expect(try parseConfig("bind = CTRL ALT, space, palette").keyBinds == [bind])
    #expect(try parseConfig(defaultConfigText).keyBinds.contains(bind))
}
