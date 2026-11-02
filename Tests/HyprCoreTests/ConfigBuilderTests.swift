import Testing
@testable import HyprCore

@Test func defaultConfigParses() throws {
    let c = try parseConfig(defaultConfigText)
    #expect(c.gapsIn == 10 && c.gapsOut == 12 && c.borderSize == 2 && c.rounding == 16)
    #expect(c.activeBorder == Gradient(colors: [RGBA(hex: 0xf5c2e7ff), RGBA(hex: 0xcba6f7ff), RGBA(hex: 0x89b4faff)], angleDegrees: 135))
    #expect(c.keyBinds.contains(KeyBind(mods: [.ctrl, .alt], key: "0", action: .workspace(10))))
    #expect(c.keyBinds.contains(KeyBind(mods: [.ctrl, .alt, .shift], key: "tab", action: .moveCurrentWorkspaceToMonitor)))
    #expect(c.keyBinds.contains(KeyBind(mods: [.ctrl, .alt], key: "minus", action: .resizeActive(dx: -50, dy: -50))))
    #expect(c.mouseBinds == [MouseBind(mods: [.ctrl, .alt], button: 272, action: .move), MouseBind(mods: [.ctrl, .alt], button: 273, action: .resize)])
    #expect(c.animations["workspaces"] == AnimationSpec(enabled: true, duration: 0.3, curve: "smooth", style: "slide"))
    #expect(c.startupWorkspace == [.builtin: 1, .external: 6])
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
    #expect(throws: ConfigError(line: 1, message: "workspace must be 1-10")) { try parseConfig("bind = CTRL, a, workspace, 11") }
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
