import Testing
@testable import BentoCore

private func commands(_ conf: String = "") throws -> [PaletteCommand] {
    paletteCommands(binds: try parseConfig("$mod = CTRL ALT\n" + conf).keyBinds)
}

private func ids(_ list: [PaletteCommand]) -> [String] { list.map(\.id) }

@Suite struct CommandPaletteTests {
    @Test func listsEveryBentoCommandOnce() throws {
        let list = try commands()
        let titles = Set(list.map(\.title))
        for n in 0...9 {
            #expect(titles.contains("Go to workspace \(n)"))
            #expect(titles.contains("Move window to workspace \(n)"))
        }
        for d in ["left", "right", "up", "down"] {
            #expect(titles.contains("Focus \(d)"))
            #expect(titles.contains("Move window \(d)"))
        }
        for t in ["Move workspace to other monitor", "Toggle split", "Toggle fullscreen", "Toggle floating", "Close window",
                  "Grow window", "Shrink window", "Window overview", "Clipboard history", "Settings…", "Pause tiling",
                  "Keep Awake", "Launch at login", "Clear clipboard history", "Quit Bento"] {
            #expect(titles.contains(t), "\(t)")
        }
        #expect(!titles.contains("Reload config"))
        #expect(!titles.contains("Open config"))
        #expect(Set(ids(list)).count == list.count)
        #expect(list.first { $0.title == "Go to workspace 3" }?.target == .action(.workspace(3)))
        #expect(list.first { $0.title == "Settings…" }?.target == .app(.settings))
    }

    @Test func userLaunchBindsBecomeCommands() throws {
        let list = try commands("""
        bind = $mod, b, focusorlaunch, Safari
        bind = $mod, return, exec, open -na Ghostty
        bind = $mod, space, palette
        bind = $mod SHIFT, b, focusorlaunch, Safari
        """)
        #expect(list.filter { $0.title == "Open Safari" }.count == 1)
        #expect(list.first { $0.title == "Open Safari" }?.target == .action(.focusOrLaunch("Safari")))
        #expect(list.first { $0.title == "Run: open -na Ghostty" }?.target == .action(.exec("open -na Ghostty")))
        #expect(!list.contains { $0.target == .action(.palette) })
    }

    @Test func terminalBindBecomesCommand() throws {
        let list = try commands("bind = $mod, return, terminal")
        let terminal = list.first { $0.title == "Open terminal" }
        #expect(terminal?.target == .action(.terminal))
        #expect(terminal?.shortcut == "⌃⌥↩")
    }

    @Test func commandsShowTheirShortcut() throws {
        let list = try commands("""
        bind = $mod, 3, workspace, 3
        bind = $mod SHIFT, left, movewindow, l
        bind = SUPER SHIFT, c, clipboard
        bind = $mod, space, palette
        bind = , mission_control, overview
        """)
        func shortcut(_ title: String) -> String? { list.first { $0.title == title }?.shortcut }
        #expect(shortcut("Go to workspace 3") == "⌃⌥3")
        #expect(shortcut("Move window left") == "⌃⌥⇧←")
        #expect(shortcut("Clipboard history") == "⇧⌘C")
        #expect(shortcut("Window overview") == "F3")
        #expect(shortcut("Go to workspace 4") == nil)
        #expect(shortcutLabel(KeyBind(mods: [.ctrl, .alt], key: "space", action: .palette)) == "⌃⌥Space")
    }

    @Test func fuzzyMatchRanksWordStartsFirst() throws {
        let list = try commands()
        #expect(rankCommands(list, query: "mtw3", recent: []).first?.title == "Move window to workspace 3")
        #expect(rankCommands(list, query: "MTW3", recent: []).first?.title == "Move window to workspace 3")
        #expect(rankCommands(list, query: "xyz", recent: []).isEmpty)
        #expect(rankCommands(list, query: "clip", recent: []).prefix(2).map(\.title)
            == ["Clipboard history", "Clear clipboard history"])
        let close = rankCommands(list, query: "close", recent: [])
        #expect(close.first?.title == "Close window")
        #expect(rankCommands(list, query: "keep", recent: []).first?.title == "Keep Awake")
        #expect(rankCommands(list, query: "s", recent: []).first?.title == "Toggle split")
    }

    @Test func recentCommandsComeFirst() throws {
        let list = try commands()
        let empty = rankCommands(list, query: "", recent: ["app:settings", "workspace:3", "nope"])
        #expect(Array(ids(empty).prefix(2)) == ["app:settings", "workspace:3"])
        #expect(empty.count == list.count)
        #expect(Array(ids(empty).dropFirst(2)) == ids(list).filter { $0 != "app:settings" && $0 != "workspace:3" })
        let recent = ["a", "b", "c", "d", "e", "workspace:9"]
        #expect(rankCommands(list, query: "", recent: recent.map { $0 == "a" ? "workspace:1" : $0 }).first?.id == "workspace:1")
        #expect(rankCommands(list, query: "", recent: recent)[0].id != "workspace:9")
        #expect(rankCommands(list, query: "go to workspace", recent: ["workspace:7"]).first?.id == "workspace:7")
    }
}
