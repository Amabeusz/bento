import Testing
@testable import HyprCore

private let M1 = MonitorInfo(id: 1, frame: Rect(x: 0, y: 0, w: 1512, h: 982), usable: Rect(x: 0, y: 33, w: 1512, h: 949), isBuiltin: true)
private let M2 = MonitorInfo(id: 2, frame: Rect(x: 1512, y: 0, w: 2560, h: 1440), usable: Rect(x: 1512, y: 25, w: 2560, h: 1415), isBuiltin: false)
private let area1 = M1.usable.inset(by: 12)
private let area2 = M2.usable.inset(by: 12)

private func makeWorld() -> World {
    var config = try! parseConfig(defaultConfigText)
    config.barEnabled = false
    let world = World(config: config)
    world.setMonitors([M1, M2])
    return world
}

private func window(_ id: WindowID, on m: MonitorInfo, app: String = "Ghostty", isDialog: Bool = false) -> WindowInfo {
    WindowInfo(id: id, app: app, title: "", isDialog: isDialog, frame: Rect(x: m.frame.x + 100, y: m.frame.y + 100, w: 400, h: 300))
}

private func parkedRect(_ p: Placement?) -> Rect? {
    if case .parked(let r) = p { return r }
    return nil
}

@Suite struct WorldTests {
    @Test func startupAssignsWindowsByMonitor() {
        let w = makeWorld()
        w.addWindow(window(1, on: M2))
        w.addWindow(window(2, on: M1))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 1, 2: 6])
        #expect(s.placements[1] == .tiled(area2))
        #expect(s.placements[2] == .tiled(area1))
        #expect(s.bars[1]?.filter { !$0.isEmpty }.map(\.number) == [1, 6])
    }

    @Test func newWindowSplitsFocused() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        let s = w.snapshot()
        #expect(s.placements[1] == .tiled(Rect(x: 12, y: 45, w: 739, h: 925)))
        #expect(s.placements[2] == .tiled(Rect(x: 761, y: 45, w: 739, h: 925)))
        #expect(s.focused == 2)
    }

    @Test func switchToHiddenWorkspaceOpensOnFocusedMonitor() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(2)
        _ = w.perform(.workspace(3))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 1, 2: 3])
        #expect(s.placements[2] == .parked(Rect(x: 4071, y: 1439, w: area2.w, h: area2.h)))
        #expect(s.placements[1] == .tiled(area1))
        #expect(s.focused == nil)
    }

    @Test func switchToVisibleWorkspaceMovesFocus() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(2)
        let effects = w.perform(.workspace(1))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 1, 2: 6])
        #expect(s.focused == 1)
        #expect(effects.contains(.focusWindow(1)))
        #expect(effects.contains(.warpCursor(Point(x: 756, y: 491))))
    }

    @Test func moveToWorkspaceKeepsFocusHere() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        w.externalFocus(2)
        let effects = w.perform(.moveToWorkspace(2))
        let s = w.snapshot()
        #expect(parkedRect(s.placements[2]) != nil)
        #expect(s.placements[1] == .tiled(area1))
        #expect(s.focused == 1)
        #expect(effects == [.focusWindow(1)])
        #expect(s.visibleWorkspace[1] == 1)
        #expect(s.bars[1]?[1].isEmpty == false)
    }

    @Test func moveWorkspaceToOtherMonitorSwaps() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(1)
        _ = w.perform(.moveCurrentWorkspaceToMonitor)
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 6, 2: 1])
        #expect(s.placements[1] == .tiled(area2))
        #expect(s.placements[2] == .tiled(area1))
        #expect(s.focused == 1)
    }

    @Test func focusOrLaunchFocusesOrLaunches() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1, app: "Safari"))
        w.externalFocus(2)
        _ = w.perform(.moveToWorkspace(4))
        #expect(parkedRect(w.snapshot().placements[2]) != nil)

        let effects = w.perform(.focusOrLaunch("Safari"))
        let s = w.snapshot()
        #expect(s.visibleWorkspace[1] == 4)
        #expect(s.focused == 2)
        #expect(s.placements[2] == .tiled(area1))
        #expect(effects.contains(.focusWindow(2)))

        #expect(w.perform(.focusOrLaunch("Notes")) == [.launchApp("Notes")])
    }

    @Test func dialogsAndRulesFloat() {
        let w = makeWorld()
        let dialog = window(1, on: M1, isDialog: true)
        let settings = window(2, on: M1, app: "System Settings")
        w.addWindow(dialog)
        w.addWindow(settings)
        let s = w.snapshot()
        #expect(s.placements[1] == .floating(dialog.frame))
        #expect(s.placements[2] == .floating(settings.frame))
    }

    @Test func unplugFocusedMonitorKeepsWindows() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.addWindow(window(3, on: M2))
        w.externalFocus(3)
        w.setMonitors([M1])
        let s = w.snapshot()
        #expect(s.focused == 1)
        #expect(s.placements.count == 3)
        #expect(s.visibleWorkspace == [1: 1])
        for id: WindowID in [2, 3] {
            let r = parkedRect(s.placements[id])
            #expect(r?.x == M1.frame.maxX - 1)
            #expect(r?.y == M1.frame.maxY - 1)
        }
        w.setMonitors([M1, M2])
        #expect(w.snapshot().visibleWorkspace == [1: 1, 2: 6])
    }

    @Test func killActiveEmitsClose() {
        let w = makeWorld()
        #expect(w.perform(.killActive) == [])
        w.addWindow(window(1, on: M1))
        #expect(w.perform(.killActive) == [.closeWindow(1)])
    }

    @Test func badgesReflectState() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        let bars = w.snapshot().bars
        #expect(bars[1]?.count == 10)
        #expect(bars[2]?.count == 10)
        #expect(bars[1]?[0] == WorkspaceBadge(number: 1, isHere: true, isOnOtherMonitor: false, isEmpty: false))
        #expect(bars[1]?[5] == WorkspaceBadge(number: 6, isHere: false, isOnOtherMonitor: true, isEmpty: true))
        #expect(bars[1]?[2] == WorkspaceBadge(number: 3, isHere: false, isOnOtherMonitor: false, isEmpty: true))
        #expect(bars[2]?[0] == WorkspaceBadge(number: 1, isHere: false, isOnOtherMonitor: true, isEmpty: false))
        #expect(bars[2]?[5] == WorkspaceBadge(number: 6, isHere: true, isOnOtherMonitor: false, isEmpty: true))
    }

    @Test func addingKnownWindowIsNoOp() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        let before = w.snapshot()
        w.addWindow(window(1, on: M2))
        #expect(w.snapshot() == before)
    }
}
