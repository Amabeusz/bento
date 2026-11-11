import Testing
@testable import BentoCore

private let sample = """
# my bento
$mod = CTRL ALT

general {
    gaps_in = 6
    gaps_out = 12  # per side works too
}

bar {
    enabled = true
    height = 30
}

bind = $mod, left, movefocus, l
bind = $mod SHIFT, q, killactive
# apps
bind = SUPER SHIFT, c, clipboard
windowrule = float, app:^Calculator$
"""

@Suite struct ConfigEditorTests {
    @Test func setReplacesValueKeepingIndentAndComment() {
        var e = ConfigEditor(text: sample)
        #expect(e.value("general:gaps_in") == "6")
        #expect(e.value("general:gaps_out") == "12")
        e.set("general:gaps_in", "10")
        e.set("general:gaps_out", "20 12 12 12")
        var expected = sample.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        expected[4] = "    gaps_in = 10"
        expected[5] = "    gaps_out = 20 12 12 12  # per side works too"
        #expect(e.text == expected.joined(separator: "\n"))
    }

    @Test func setInsertsMissingKeyIntoSection() {
        var e = ConfigEditor(text: sample)
        e.set("bar:padding", "15")
        let lines = e.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(Array(lines[8...12]) == ["bar {", "    enabled = true", "    height = 30", "    padding = 15", "}"])
        #expect(e.value("bar:padding") == "15")
    }

    @Test func setAppendsMissingSection() {
        var e = ConfigEditor(text: sample)
        e.set("clipboard:history_size", "50")
        #expect(e.text.hasSuffix("windowrule = float, app:^Calculator$\n\nclipboard {\n    history_size = 50\n}"))
        e.set("clipboard:keep_awake_on_launch", "true")
        #expect(e.text.hasSuffix("clipboard {\n    history_size = 50\n    keep_awake_on_launch = true\n}"))
    }

    @Test func removeDeletesLine() {
        var e = ConfigEditor(text: sample)
        e.remove("bar:height")
        #expect(!e.text.contains("height = 30"))
        #expect(e.value("bar:height") == nil)
        #expect(e.text.contains("bar {\n    enabled = true\n}"))
    }

    @Test func bindsKeepSourceModsAndEditOnlyTheirLine() {
        var e = ConfigEditor(text: sample)
        let binds = e.binds
        #expect(binds.map(\.mods) == ["$mod", "$mod SHIFT", "SUPER SHIFT"])
        #expect(binds.map(\.key) == ["left", "q", "c"])
        #expect(binds.map(\.dispatcher) == ["movefocus", "killactive", "clipboard"])
        #expect(binds.map(\.args) == ["l", "", ""])

        var changed = binds[1]
        changed.key = "w"
        e.setBind(changed)
        #expect(e.text.contains("bind = $mod SHIFT, w, killactive\n# apps"))

        e.addBind(EditableBind(mods: "$mod", key: "b", dispatcher: "focusorlaunch", args: "Safari"))
        #expect(e.text.contains("bind = SUPER SHIFT, c, clipboard\nbind = $mod, b, focusorlaunch, Safari\nwindowrule"))

        e.removeBind(at: e.binds[0].line)
        #expect(e.binds.map(\.key) == ["w", "c", "b"])
        #expect(e.text.contains("height = 30\n}\n\nbind = $mod SHIFT, w, killactive"))
    }

    @Test func modVariableRoundTrip() throws {
        var e = ConfigEditor(text: sample)
        #expect(e.mod == "CTRL ALT")
        e.setMod("CMD ALT")
        #expect(e.text.hasPrefix("# my bento\n$mod = CMD ALT\n"))
        let binds = try parseConfig(e.text).keyBinds
        #expect(binds.first { $0.key == "left" }?.mods == [.cmd, .alt])
        #expect(binds.first { $0.key == "q" }?.mods == [.cmd, .alt, .shift])
        #expect(binds.first { $0.key == "c" }?.mods == [.cmd, .shift])
    }

    @Test func colorAndValuesRoundTripThroughParser() throws {
        let color = RGBA(r: 0x37 / 255.0, g: 0x8a / 255.0, b: 0xdd / 255.0, a: 0x80 / 255.0)
        #expect(formatColor(color) == "rgba(378add80)")
        #expect(formatColor(RGBA(r: 1, g: 0, b: 0.5, a: 1)) == "rgba(ff0080ff)")
        var e = ConfigEditor(text: sample)
        e.set("bar:col.background", formatColor(color))
        e.set("general:gaps_in", "4")
        e.set("bar:enabled", "false")
        let config = try parseConfig(e.text)
        #expect(config.barBackground == color)
        #expect(config.gapsIn == 4)
        #expect(!config.barEnabled)
        #expect(config.keyBinds.count == 3)
    }

    @Test func gradientRoundTripsThroughParser() throws {
        let text = "rgba(f5c2e7ff) rgba(cba6f7ff) rgba(89b4faff) 135deg"
        let gradient = try #require(parseGradient(text))
        #expect(gradient == Gradient(colors: [RGBA(hex: 0xf5c2e7ff), RGBA(hex: 0xcba6f7ff), RGBA(hex: 0x89b4faff)],
                                     angleDegrees: 135))
        #expect(formatGradient(gradient) == text)
        let single = Gradient(colors: [RGBA(hex: 0x585b70aa)], angleDegrees: 90)
        #expect(formatGradient(single) == "rgba(585b70aa)")
        var e = ConfigEditor(text: sample)
        e.set("general:col.active_border", formatGradient(gradient))
        e.set("general:col.inactive_border", formatGradient(single))
        let config = try parseConfig(e.text)
        #expect(config.activeBorder == gradient)
        #expect(config.inactiveBorder == Gradient(colors: single.colors, angleDegrees: 0))
    }

    @Test func defaultColorsRoundTripThroughParser() throws {
        let d = Config()
        let island: [(String, RGBA)] = [
            ("bar:col.background", d.barBackground), ("bar:col.active", d.barActive),
            ("bar:col.other_monitor", d.barOtherMonitor), ("bar:col.text", d.barText),
            ("bar:col.text_active", d.barTextActive), ("bar:col.text_empty", d.barTextEmpty),
            ("bar:col.error", d.barError),
        ]
        var e = ConfigEditor(text: sample)
        e.set("general:col.active_border", formatGradient(d.activeBorder))
        e.set("general:col.inactive_border", formatGradient(d.inactiveBorder))
        for (key, color) in island { e.set(key, formatColor(color)) }
        let config = try parseConfig(e.text)
        #expect(config.activeBorder == d.activeBorder)
        #expect(config.inactiveBorder == d.inactiveBorder)
        #expect([config.barBackground, config.barActive, config.barOtherMonitor, config.barText,
                 config.barTextActive, config.barTextEmpty, config.barError] == island.map(\.1))
    }

    @Test func invalidGradientAndInsetsParseToNil() {
        #expect(parseGradient("rgba(f5c2e7ff) rgba(dd) rgba(89b4faff) 135deg") == nil)
        #expect(parseGradient("") == nil)
        #expect(parseInsets("12 x") == nil)
        #expect(parseInsets("1 2 3 4 5") == nil)
    }

    @Test func insetsRoundTripThroughParser() throws {
        #expect(parseInsets("12") == Insets(all: 12))
        #expect(parseInsets("20 12") == Insets(top: 20, right: 12, bottom: 20, left: 12))
        let sides = Insets(top: 20, right: 12, bottom: 8, left: 4)
        #expect(formatInsets(sides, perSide: true) == "20 12 8 4")
        #expect(formatInsets(Insets(all: 12), perSide: false) == "12")
        #expect(formatInsets(Insets(all: 12), perSide: true) == "12 12 12 12")
        var e = ConfigEditor(text: sample)
        e.set("general:gaps_out", formatInsets(sides, perSide: true))
        #expect(try parseConfig(e.text).gapsOut == sides)
        #expect(e.value("general:gaps_out") == "20 12 8 4")
    }
}
