import Testing
@testable import BentoCore

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

private let E1 = MonitorInfo(id: 1, frame: M1.frame, usable: M1.usable, isBuiltin: false)

private func makeTwoExternalWorld() -> World {
    var config = try! parseConfig(defaultConfigText)
    config.barEnabled = false
    let world = World(config: config)
    world.setMonitors([E1, M2])
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
        #expect(s.visibleWorkspace == [1: 0, 2: 1])
        #expect(s.placements[1] == .tiled(area2))
        #expect(s.placements[2] == .tiled(area1))
        #expect(s.bars[1]?.filter { !$0.isEmpty }.map(\.number) == [0])
        #expect(s.bars[2]?.filter { !$0.isEmpty }.map(\.number) == [1])
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
        #expect(s.visibleWorkspace == [1: 0, 2: 3])
        #expect(s.placements[2] == .parked(Rect(x: 4071, y: 1439, w: area2.w, h: area2.h)))
        #expect(s.placements[1] == .tiled(area1))
        #expect(s.focused == nil)
    }

    @Test func switchToVisibleWorkspaceMovesFocus() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(2)
        let effects = w.perform(.workspace(0))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 0, 2: 1])
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
        #expect(s.visibleWorkspace[1] == 0)
        #expect(s.bars[2]?.first { $0.number == 2 }?.isEmpty == false)
    }

    @Test func moveWorkspaceToOtherMonitorSwapsWithoutBuiltin() {
        let w = makeTwoExternalWorld()
        w.addWindow(window(1, on: E1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(1)
        _ = w.perform(.moveCurrentWorkspaceToMonitor)
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 2, 2: 1])
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
        #expect(s.visibleWorkspace[2] == 4)
        #expect(s.focused == 2)
        #expect(s.placements[2] == .tiled(area2))
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
        #expect(s.focused == 3)
        #expect(s.placements.count == 3)
        #expect(s.visibleWorkspace == [1: 1])
        let r = parkedRect(s.placements[1])
        #expect(r?.x == M1.frame.maxX - 1)
        #expect(r?.y == M1.frame.maxY - 1)
        w.setMonitors([M1, M2])
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 1])
    }

    @Test func killActiveEmitsClose() {
        let w = makeWorld()
        #expect(w.perform(.killActive) == [])
        w.addWindow(window(1, on: M1))
        #expect(w.perform(.killActive) == [.closeWindow(1)])
    }

    @Test func badgeIconsOnePerAppInLayoutOrder() {
        let w = makeWorld()
        w.addWindow(window(5, on: M1))
        w.addWindow(window(3, on: M1, app: "Safari"))
        w.addWindow(window(7, on: M1))
        w.addWindow(window(1, on: M1, app: "Finder", isDialog: true))
        #expect(w.snapshot().bars[1]?[0].icons == [5, 3, 1])
        #expect(w.snapshot().bars[2]?[0].icons == [])
    }

    @Test func badgeIconsOffInConfig() {
        var config = try! parseConfig(defaultConfigText)
        config.barIcons = false
        let w = World(config: config)
        w.setMonitors([M1, M2])
        w.addWindow(window(1, on: M1))
        #expect(w.snapshot().bars[1]?[0].icons == [])
    }

    @Test func badgesReflectState() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        let bars = w.snapshot().bars
        #expect(bars[1] == [WorkspaceBadge(number: 0, isHere: true, isOnOtherMonitor: false, isEmpty: false, icons: [1])])
        #expect(bars[2]?.count == 9)
        #expect(bars[2]?[0] == WorkspaceBadge(number: 1, isHere: true, isOnOtherMonitor: false, isEmpty: true))
        #expect(bars[2]?[4] == WorkspaceBadge(number: 5, isHere: false, isOnOtherMonitor: false, isEmpty: true))

        let e = makeTwoExternalWorld()
        e.addWindow(window(1, on: E1))
        let both = e.snapshot().bars
        #expect(both[1]?.count == 9)
        #expect(both[1]?[0] == WorkspaceBadge(number: 1, isHere: true, isOnOtherMonitor: false, isEmpty: false, icons: [1]))
        #expect(both[1]?[1] == WorkspaceBadge(number: 2, isHere: false, isOnOtherMonitor: true, isEmpty: true))
    }

    @Test func verticalArrowCyclesMonitors() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(1)
        #expect(w.perform(.moveFocus(.right)) == [])
        #expect(w.snapshot().focused == 1)
        #expect(w.perform(.moveFocus(.up)) == [.focusWindow(2), .warpCursor(M2.frame.center)])
        #expect(w.perform(.moveFocus(.up)) == [.focusWindow(1), .warpCursor(M1.frame.center)])
        #expect(w.perform(.moveFocus(.down)) == [.focusWindow(2), .warpCursor(M2.frame.center)])
        #expect(w.perform(.moveFocus(.down)) == [.focusWindow(1), .warpCursor(M1.frame.center)])
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 1])
    }

    @Test func verticalArrowToEmptyMonitorFocusesNothing() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.externalFocus(1)
        #expect(w.perform(.moveFocus(.down)) == [.focusNothing, .warpCursor(M2.frame.center)])
        #expect(w.snapshot().focused == nil)
    }

    @Test func verticalArrowOnSingleScreenDoesNothing() {
        let w = singleScreenWorld()
        w.addWindow(window(1, on: M1))
        #expect(w.perform(.moveFocus(.up)) == [])
        #expect(w.perform(.moveFocus(.down)) == [])
        #expect(w.snapshot().focused == 1)
    }

    @Test func verticalArrowFollowsLeftToRightOrder() {
        let right = MonitorInfo(id: 2, frame: M2.frame, usable: M2.usable, isBuiltin: false)
        let left = MonitorInfo(id: 3, frame: leftExternal.frame, usable: leftExternal.usable, isBuiltin: false)
        let w = World(config: try! parseConfig(defaultConfigText))
        w.setMonitors([right, E1, left])
        w.addWindow(window(1, on: E1))
        w.externalFocus(1)
        #expect(w.perform(.moveFocus(.down)) == [.focusNothing, .warpCursor(right.frame.center)])
        #expect(w.perform(.moveFocus(.down)) == [.focusNothing, .warpCursor(left.frame.center)])
        #expect(w.perform(.moveFocus(.up)) == [.focusNothing, .warpCursor(right.frame.center)])
    }

    @Test func verticalArrowGoesToWindowBelowBeforeMonitor() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        w.addWindow(window(3, on: M1))
        w.addWindow(window(4, on: M2))
        w.externalFocus(2)
        #expect(w.perform(.moveFocus(.down)) == [.focusWindow(3)])
        #expect(w.perform(.moveFocus(.down)) == [.focusWindow(4), .warpCursor(M2.frame.center)])
    }

    @Test func moveWindowVerticallyCyclesMonitors() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(1)
        #expect(w.perform(.moveWindow(.down)) == [.focusWindow(1), .warpCursor(M2.frame.center)])
        var s = w.snapshot()
        #expect(s.focused == 1)
        #expect(s.bars[1]?[0].isEmpty == true)
        if case .tiled(let r) = s.placements[1] { #expect(M2.frame.contains(r.center)) } else { Issue.record("not tiled") }
        #expect(w.perform(.moveWindow(.down)) == [.focusWindow(1), .warpCursor(M1.frame.center)])
        s = w.snapshot()
        #expect(s.placements[1] == .tiled(area1))
        #expect(w.perform(.moveWindow(.up)) == [.focusWindow(1), .warpCursor(M2.frame.center)])
        #expect(w.snapshot().bars[2]?[0].isEmpty == false)

        let one = singleScreenWorld()
        one.addWindow(window(1, on: M1))
        #expect(one.perform(.moveWindow(.down)) == [])
        #expect(one.perform(.moveWindow(.up)) == [])
    }

    @Test func moveWindowDownSwapsWithWindowBelowFirst() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        w.addWindow(window(3, on: M1))
        w.externalFocus(2)
        let before = w.snapshot()
        #expect(w.perform(.moveWindow(.down)) == [])
        let after = w.snapshot()
        #expect(after.placements[2] == before.placements[3])
        #expect(after.placements[3] == before.placements[2])
    }

    @Test func moveWindowRightGoesToNextWorkspaceOnSameMonitor() {
        let w = singleScreenWorld()
        w.addWindow(window(1, on: M1))
        #expect(w.perform(.moveWindow(.right)) == [.focusWindow(1)])
        var s = w.snapshot()
        #expect(s.visibleWorkspace[1] == 2)
        #expect(s.focused == 1)
        #expect(s.bars[1]?.filter { !$0.isEmpty }.map(\.number) == [2])
        #expect(w.perform(.moveWindow(.left)) == [.focusWindow(1)])
        s = w.snapshot()
        #expect(s.visibleWorkspace[1] == 1)
        #expect(s.bars[1]?.filter { !$0.isEmpty }.map(\.number) == [1])
        #expect(w.perform(.moveWindow(.left)) == [])
        _ = w.perform(.moveToWorkspace(9))
        _ = w.perform(.workspace(9))
        #expect(w.perform(.moveWindow(.right)) == [])
        #expect(w.snapshot().bars[1]?.filter { !$0.isEmpty }.map(\.number) == [9])
    }

    @Test func moveWindowHorizontallyNeverLeavesMonitor() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(1)
        #expect(w.perform(.moveWindow(.right)) == [])
        #expect(w.snapshot().bars[1]?[0].isEmpty == false)
        w.externalFocus(2)
        #expect(w.perform(.moveWindow(.left)) == [])
        #expect(w.perform(.moveWindow(.right)) == [.focusWindow(2)])
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 0, 2: 2])
        #expect(s.placements[2] == .tiled(area2))

        let e = makeTwoExternalWorld()
        e.addWindow(window(1, on: E1))
        e.externalFocus(1)
        #expect(e.perform(.moveWindow(.right)) == [])
        #expect(e.snapshot().visibleWorkspace[1] == 1)

        let p = makeWorld()
        p.addWindow(window(1, on: M1))
        p.addWindow(window(2, on: M2))
        p.externalFocus(2)
        _ = p.perform(.workspace(3))
        p.externalFocus(1)
        #expect(p.perform(.moveWindow(.right)) == [])
        #expect(p.snapshot().bars[1]?[0].isEmpty == false)
    }

    @Test func moveWindowUpGoesToPreviousMonitorInLeftToRightOrder() {
        let right = MonitorInfo(id: 2, frame: M2.frame, usable: M2.usable, isBuiltin: false)
        let left = MonitorInfo(id: 3, frame: leftExternal.frame, usable: leftExternal.usable, isBuiltin: false)
        let w = World(config: try! parseConfig(defaultConfigText))
        w.setMonitors([right, E1, left])
        w.addWindow(window(1, on: E1))
        w.externalFocus(1)
        #expect(w.perform(.moveWindow(.up)) == [.focusWindow(1), .warpCursor(left.frame.center)])
        #expect(w.perform(.moveWindow(.down)) == [.focusWindow(1), .warpCursor(E1.frame.center)])
        #expect(w.perform(.moveWindow(.down)) == [.focusWindow(1), .warpCursor(right.frame.center)])
    }

    @Test func removingFocusedFallsBackToRecentInWorkspace() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        w.addWindow(window(3, on: M1))
        w.externalFocus(1)
        w.removeWindow(2)
        #expect(w.snapshot().focused == 1)
        w.removeWindow(1)
        #expect(w.snapshot().focused == 3)
        w.removeWindow(3)
        #expect(w.snapshot().focused == nil)
    }

    @Test func moveFocusAndMoveWindowWithinWorkspace() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        let left = Rect(x: 12, y: 45, w: 739, h: 925)
        let right = Rect(x: 761, y: 45, w: 739, h: 925)
        #expect(w.perform(.moveFocus(.left)) == [.focusWindow(1)])
        #expect(w.perform(.moveWindow(.right)) == [])
        let s = w.snapshot()
        #expect(s.focused == 1)
        #expect(s.placements[1] == .tiled(right))
        #expect(s.placements[2] == .tiled(left))
    }

    @Test func fullscreenFillsTilingArea() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        _ = w.perform(.fullscreen)
        #expect(w.snapshot().placements[2] == .tiled(area1))
        #expect(w.snapshot().placements[1] == .tiled(Rect(x: 12, y: 45, w: 739, h: 925)))
        _ = w.perform(.fullscreen)
        #expect(w.snapshot().placements[2] == .tiled(Rect(x: 761, y: 45, w: 739, h: 925)))
    }

    @Test func toggleFloatingBothWays() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        let right = Rect(x: 761, y: 45, w: 739, h: 925)
        _ = w.perform(.toggleFloating)
        #expect(w.snapshot().placements[2] == .floating(right))
        #expect(w.snapshot().placements[1] == .tiled(area1))
        _ = w.perform(.toggleFloating)
        #expect(w.snapshot().placements[2] == .tiled(right))
        #expect(w.snapshot().placements[1] == .tiled(Rect(x: 12, y: 45, w: 739, h: 925)))
    }

    @Test func resizeFloatingKeepsTopLeft() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1, isDialog: true))
        _ = w.perform(.resizeActive(dx: 50, dy: -20))
        #expect(w.snapshot().placements[1] == .floating(Rect(x: 100, y: 100, w: 450, h: 280)))
    }

    @Test func moveWorkspaceToEmptyOtherMonitorWithoutBuiltin() {
        let w = makeTwoExternalWorld()
        w.addWindow(window(1, on: E1))
        w.externalFocus(1)
        _ = w.perform(.moveCurrentWorkspaceToMonitor)
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 2, 2: 1])
        #expect(s.placements[1] == .tiled(area2))
        #expect(s.focused == 1)
    }

    @Test func floatingWindowFollowsWorkspaceToOtherMonitor() {
        let w = makeTwoExternalWorld()
        w.addWindow(window(1, on: E1))
        w.addWindow(window(2, on: M2, app: "Finder", isDialog: true))
        w.externalFocus(2)
        _ = w.perform(.moveCurrentWorkspaceToMonitor)
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 2, 2: 1])
        #expect(s.placements[2] == .floating(Rect(x: 100, y: 108, w: 400, h: 300)))
    }

    @Test func replugPinsBuiltinAndMovesItsWorkspaceToExternal() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(2)
        w.setMonitors([M1])
        _ = w.perform(.workspace(6))
        #expect(w.snapshot().visibleWorkspace == [1: 6])
        w.setMonitors([M1, M2])
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 6])
    }

    @Test func externalFocusOnHiddenWorkspaceShowsIt() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M1))
        _ = w.perform(.moveToWorkspace(3))
        w.externalFocus(2)
        let s = w.snapshot()
        #expect(s.visibleWorkspace[2] == 3)
        #expect(s.focused == 2)
        #expect(s.placements[2] == .tiled(area2))
        #expect(s.placements[1] == .tiled(area1))
    }

    @Test func switchingToEmptyWorkspaceFocusesNothing() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.externalFocus(1)
        #expect(w.perform(.workspace(3)).contains(.focusNothing))
        #expect(w.snapshot().focused == nil)
    }

    @Test func sendingLastWindowAwayFocusesNothing() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.externalFocus(1)
        #expect(w.perform(.moveToWorkspace(2)) == [.focusNothing])
        #expect(w.snapshot().focused == nil)
    }

    @Test func floatingResizeStopsAtMinimumSize() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1, isDialog: true))
        _ = w.perform(.resizeActive(dx: -1000, dy: -1000))
        #expect(w.snapshot().placements[1] == .floating(Rect(x: 100, y: 100, w: 100, h: 60)))
    }

    @Test func floatingFrameStopsAtMinimumSize() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1, isDialog: true))
        w.setFloatingFrame(1, Rect(x: 200, y: 150, w: 20, h: 10))
        #expect(w.snapshot().placements[1] == .floating(Rect(x: 200, y: 150, w: 100, h: 60)))
    }

    @Test func smallFloatingWindowMovesWithoutGrowing() {
        let w = makeWorld()
        w.addWindow(WindowInfo(id: 1, app: "Ghostty", title: "", isDialog: true, frame: Rect(x: 100, y: 100, w: 80, h: 40)))
        w.setFloatingFrame(1, Rect(x: 300, y: 200, w: 80, h: 40))
        #expect(w.snapshot().placements[1] == .floating(Rect(x: 300, y: 200, w: 80, h: 40)))
    }

    @Test func addingKnownWindowIsNoOp() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        let before = w.snapshot()
        w.addWindow(window(1, on: M2))
        #expect(w.snapshot() == before)
    }

    @Test func hiddenWorkspaceOpensOnExternalWhenTwoMonitors() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.externalFocus(1)
        let effects = w.perform(.workspace(3))
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 3])
        #expect(effects.contains(.warpCursor(M2.frame.center)))
    }

    @Test func workspaceOneFocusesBuiltin() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        w.externalFocus(2)
        let effects = w.perform(.workspace(0))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 0, 2: 1])
        #expect(s.focused == 1)
        #expect(effects.contains(.warpCursor(M1.frame.center)))
    }

    @Test func pluggingExternalMovesCurrentWorkspaceThere() {
        var config = try! parseConfig(defaultConfigText)
        config.barEnabled = false
        let w = World(config: config)
        w.setMonitors([M1])
        w.addWindow(window(1, on: M1))
        _ = w.perform(.workspace(3))
        w.addWindow(window(2, on: M1))
        w.setMonitors([M1, M2])
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 0, 2: 3])
        #expect(parkedRect(s.placements[1]) != nil)
        #expect(s.placements[2] == .tiled(area2))
    }

    @Test func moveWorkspaceToMonitorIsNoOpWithPinnedBuiltin() {
        let w = makeWorld()
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: M2))
        #expect(w.perform(.moveCurrentWorkspaceToMonitor) == [])
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 1])
    }

    @Test func badgesSplitBetweenBuiltinAndExternal() {
        let s = makeWorld().snapshot()
        #expect(s.bars[1]?.map(\.number) == [0])
        #expect(s.bars[2]?.map(\.number) == Array(1...9))
    }

    @Test func singleMonitorKeepsAllWorkspaces() {
        var config = try! parseConfig(defaultConfigText)
        config.barEnabled = false
        let w = World(config: config)
        w.setMonitors([M1])
        _ = w.perform(.workspace(3))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 3])
        #expect(s.bars[1]?.map(\.number) == Array(1...9))
    }

    @Test func openingLidPinsWorkspaceZeroToBuiltin() {
        var config = try! parseConfig(defaultConfigText)
        config.barEnabled = false
        let w = World(config: config)
        w.setMonitors([M2])
        _ = w.perform(.workspace(1))
        w.setMonitors([M1, M2])
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 1])
    }

    @Test func arrowPastLastWindowGoesToNextWorkspace() {
        let w = singleMonitorWithWindowsOnOneAndThree()
        let effects = w.perform(.moveFocus(.right))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 3])
        #expect(s.focused == 2)
        #expect(effects.contains(.focusWindow(2)))
    }

    @Test func arrowLeftGoesToPreviousNonEmptyWorkspace() {
        let w = singleMonitorWithWindowsOnOneAndThree()
        _ = w.perform(.moveFocus(.right))
        #expect(w.snapshot().visibleWorkspace == [1: 3])
        _ = w.perform(.moveFocus(.left))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 1])
        #expect(s.focused == 1)
    }

    @Test func arrowWithNoWorkspaceBeyondDoesNothing() {
        let w = singleMonitorWithWindowsOnOneAndThree()
        #expect(w.perform(.moveFocus(.left)) == [])
        _ = w.perform(.moveFocus(.right))
        #expect(w.perform(.moveFocus(.right)) == [])
        #expect(w.snapshot().visibleWorkspace == [1: 3])
    }

    @Test func verticalArrowDoesNotSwitchWorkspace() {
        let w = singleMonitorWithWindowsOnOneAndThree()
        _ = w.perform(.moveFocus(.right))
        #expect(w.perform(.moveFocus(.up)) == [])
        #expect(w.perform(.moveFocus(.down)) == [])
        #expect(w.snapshot().visibleWorkspace == [1: 3])
    }

    @Test func arrowOnExternalStaysWithinItsWorkspaces() {
        let left = MonitorInfo(id: 2, frame: Rect(x: -2560, y: 0, w: 2560, h: 1440), usable: Rect(x: -2560, y: 25, w: 2560, h: 1415), isBuiltin: false)
        var config = try! parseConfig(defaultConfigText)
        config.barEnabled = false
        let w = World(config: config)
        w.setMonitors([M1, left])
        w.addWindow(window(1, on: M1))
        w.addWindow(window(2, on: left))
        w.addWindow(window(3, on: left))
        w.externalFocus(3)
        _ = w.perform(.moveToWorkspace(3))
        w.externalFocus(1)
        #expect(w.perform(.moveFocus(.right)) == [])
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 1])
        w.externalFocus(2)
        _ = w.perform(.workspace(5))
        _ = w.perform(.moveFocus(.left))
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 3])
    }

    @Test func horizontalArrowNeverLeavesMonitor() {
        let w = externalLeftOfMacBookWithWindowsOnOneAndThree()
        w.externalFocus(2)
        _ = w.perform(.moveFocus(.right))
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 3])
        #expect(w.snapshot().focused == 3)
        _ = w.perform(.moveFocus(.left))
        #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 1])
        #expect(w.snapshot().focused == 2)
        w.externalFocus(1)
        #expect(w.perform(.moveFocus(.left)) == [])
        #expect(w.perform(.moveFocus(.right)) == [])
        #expect(w.snapshot().focused == 1)
    }

    @Test func horizontalArrowActsOnMonitorReachedByVerticalArrow() {
        let w = externalLeftOfMacBookWithWindowsOnOneAndThree()
        w.externalFocus(1)
        #expect(w.perform(.moveFocus(.up)) == [.focusWindow(2), .warpCursor(leftExternal.frame.center)])
        _ = w.perform(.moveFocus(.right))
        let s = w.snapshot()
        #expect(s.visibleWorkspace == [1: 0, 2: 3])
        #expect(s.focused == 3)
    }
}

private let leftExternal = MonitorInfo(id: 2, frame: Rect(x: -2560, y: 0, w: 2560, h: 1440), usable: Rect(x: -2560, y: 25, w: 2560, h: 1415), isBuiltin: false)

private func externalLeftOfMacBookWithWindowsOnOneAndThree() -> World {
    var config = try! parseConfig(defaultConfigText)
    config.barEnabled = false
    let w = World(config: config)
    w.setMonitors([M1, leftExternal])
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: leftExternal))
    w.addWindow(window(3, on: leftExternal))
    w.externalFocus(3)
    _ = w.perform(.moveToWorkspace(3))
    return w
}

private func singleMonitorWithWindowsOnOneAndThree() -> World {
    var config = try! parseConfig(defaultConfigText)
    config.barEnabled = false
    let w = World(config: config)
    w.setMonitors([M1])
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M1))
    w.externalFocus(2)
    _ = w.perform(.moveToWorkspace(3))
    return w
}

private func singleWindowWorld(_ configure: (inout Config) -> Void) -> World {
    var config = try! parseConfig(defaultConfigText)
    configure(&config)
    let world = World(config: config)
    world.setMonitors([M1])
    world.addWindow(window(1, on: M1))
    return world
}

@Test func gapsOutApplyPerSide() {
    let w = singleWindowWorld {
        $0.barEnabled = false
        $0.gapsOut = Insets(top: 20, right: 5, bottom: 10, left: 30)
    }
    let u = M1.usable
    #expect(w.snapshot().placements[1] == .tiled(Rect(x: u.x + 30, y: u.y + 20, w: u.w - 35, h: u.h - 30)))
}

@Test func barMarginsReserveSpaceAboveTiles() {
    let w = singleWindowWorld {
        $0.barHeight = 30
        $0.barMarginTop = 6
        $0.barMarginBottom = 10
    }
    let u = M1.usable
    #expect(w.snapshot().placements[1] == .tiled(Rect(x: u.x + 12, y: u.y + 46 + 12, w: u.w - 24, h: u.h - 46 - 24)))

}

private func singleScreenWorld() -> World {
    var config = try! parseConfig(defaultConfigText)
    config.barEnabled = false
    let w = World(config: config)
    w.setMonitors([M1])
    return w
}

@Test func builtinIsZeroAndExternalHasOneToNine() {
    let s = makeWorld().snapshot()
    #expect(s.visibleWorkspace == [1: 0, 2: 1])
    #expect(s.bars[1]?.map(\.number) == [0])
    #expect(s.bars[2]?.map(\.number) == Array(1...9))
}

@Test func zeroFocusesBuiltinOthersOpenOnExternal() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M2))
    w.externalFocus(2)
    let effects = w.perform(.workspace(0))
    #expect(w.snapshot().focused == 1)
    #expect(effects.contains(.warpCursor(M1.frame.center)))
    _ = w.perform(.workspace(3))
    #expect(w.snapshot().visibleWorkspace == [1: 0, 2: 3])
}

@Test func singleScreenHasOneToNineOnly() {
    let w = singleScreenWorld()
    w.addWindow(window(1, on: M1))
    #expect(w.perform(.workspace(0)) == [])
    #expect(w.perform(.moveToWorkspace(0)) == [])
    let s = w.snapshot()
    #expect(s.visibleWorkspace == [1: 1])
    #expect(s.placements[1] == .tiled(area1))
    #expect(s.bars[1]?.map(\.number) == Array(1...9))
}

@Test func unplugMovesZeroWindowsToLowestEmpty() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M2))
    w.setMonitors([M1])
    let s = w.snapshot()
    #expect(s.visibleWorkspace == [1: 1])
    #expect(s.placements[2] == .tiled(area1))
    #expect(parkedRect(s.placements[1]) != nil)
    #expect(s.bars[1]?.first { $0.number == 2 }?.isEmpty == false)
}

@Test func replugPinsZeroAndMovesCurrentToExternal() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M2))
    w.setMonitors([M1])
    _ = w.perform(.workspace(2))
    w.setMonitors([M1, M2])
    let s = w.snapshot()
    #expect(s.visibleWorkspace == [1: 0, 2: 2])
    #expect(s.placements[1] == .tiled(area2))
}


@Test func unplugShowsTheExternalsWorkspaceOnMacBook() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M2))
    w.externalFocus(2)
    _ = w.perform(.moveToWorkspace(3))
    _ = w.perform(.workspace(3))
    w.setMonitors([M1])
    let s = w.snapshot()
    #expect(s.visibleWorkspace == [1: 3])
    #expect(s.placements[2] == .tiled(area1))
}

@Test func unplugMovesFocusOffTheHiddenZeroWindow() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M2))
    w.externalFocus(1)
    w.setMonitors([M1])
    let s = w.snapshot()
    #expect(parkedRect(s.placements[1]) != nil)
    #expect(s.focused == 2)
}

@Test func unplugWithEmptyExternalWorkspaceFocusesNothing() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(2, on: M2))
    w.externalFocus(2)
    _ = w.perform(.moveToWorkspace(4))
    _ = w.perform(.workspace(3))
    w.externalFocus(1)
    w.setMonitors([M1])
    let s = w.snapshot()
    #expect(s.visibleWorkspace == [1: 3])
    #expect(parkedRect(s.placements[1]) != nil)
    #expect(s.focused == nil)
}

@Test func dialogCentersOverItsAppWindow() {
    let w = singleScreenWorld()
    w.addWindow(window(1, on: M1, app: "Safari"))
    w.addWindow(window(2, on: M1, app: "Safari", isDialog: true))
    #expect(w.snapshot().placements[2] == .floating(Rect(x: 556, y: 357.5, w: 400, h: 300)))

    let two = makeWorld()
    two.addWindow(window(1, on: M2, app: "Safari"))
    two.addWindow(window(2, on: M1, app: "Ghostty"))
    two.externalFocus(2)
    two.addWindow(window(3, on: M1, app: "Safari", isDialog: true))
    let c = area2.center
    #expect(two.snapshot().placements[3] == .floating(Rect(x: c.x - 200, y: c.y - 150, w: 400, h: 300)))
    two.externalFocus(1)
    _ = two.perform(.workspace(5))
    #expect(parkedRect(two.snapshot().placements[3]) != nil)
}

@Test func dialogOverAppStaysOnScreen() {
    let w = singleScreenWorld()
    w.addWindow(window(1, on: M1, app: "Safari"))
    w.addWindow(WindowInfo(id: 2, app: "Safari", title: "", isDialog: true, frame: Rect(x: 0, y: 0, w: 3000, h: 2000)))
    #expect(w.snapshot().placements[2] == .floating(M1.usable))
}

@Test func dialogWithoutAppWindowKeepsItsFrame() {
    let w = singleScreenWorld()
    w.addWindow(window(1, on: M1, app: "Ghostty"))
    let dialog = window(2, on: M1, app: "Safari", isDialog: true)
    w.addWindow(dialog)
    #expect(w.snapshot().placements[2] == .floating(dialog.frame))
}

@Test func secondNormalWindowStillTiles() {
    let w = singleScreenWorld()
    w.addWindow(window(1, on: M1, app: "Safari"))
    w.addWindow(window(2, on: M1, app: "Safari"))
    guard case .tiled = w.snapshot().placements[2] else { Issue.record("not tiled"); return }
}

@Test func rememberedWindowReturnsToItsWorkspace() {
    let w = makeWorld()
    w.remember([WindowMemory(id: 1, app: "Ghostty", workspace: 5)])
    w.addWindow(window(1, on: M2))
    let s = w.snapshot()
    #expect(parkedRect(s.placements[1]) != nil)
    #expect(s.bars[2]?.filter { !$0.isEmpty }.map(\.number) == [5])
}

@Test func rememberedIdOfAnotherAppIsIgnored() {
    let w = makeWorld()
    w.remember([WindowMemory(id: 1, app: "Safari", workspace: 5)])
    w.addWindow(window(1, on: M2))
    #expect(w.snapshot().placements[1] == .tiled(area2))
}

@Test func rememberedUnavailableWorkspaceIsIgnored() {
    let w = singleScreenWorld()
    w.remember([WindowMemory(id: 1, app: "Ghostty", workspace: 0)])
    w.addWindow(window(1, on: M1))
    #expect(w.snapshot().placements[1] == .tiled(area1))
}

@Test func memoryFollowsMovesAndKeepsUnseen() {
    let w = makeWorld()
    w.remember([WindowMemory(id: 1, app: "Ghostty", workspace: 5), WindowMemory(id: 9, app: "Safari", workspace: 7)])
    w.addWindow(window(1, on: M2))
    w.addWindow(window(2, on: M2))
    _ = w.perform(.moveToWorkspace(3))
    #expect(w.memory == [
        WindowMemory(id: 1, app: "Ghostty", workspace: 5),
        WindowMemory(id: 2, app: "Ghostty", workspace: 3),
        WindowMemory(id: 9, app: "Safari", workspace: 7),
    ])
}

@Test func overviewListsEveryWorkspaceOfTheMonitorInLayoutOrder() {
    let w = makeWorld()
    w.addWindow(window(1, on: M1))
    w.addWindow(window(5, on: M2))
    w.addWindow(window(3, on: M2))
    w.addWindow(window(9, on: M2))
    w.externalFocus(9)
    _ = w.perform(.moveToWorkspace(3))
    w.addWindow(window(2, on: M2, app: "Finder", isDialog: true))
    let s = w.snapshot()
    func tiled(_ p: Placement?) -> Rect? { if case .tiled(let r) = p { r } else { nil } }
    func floated(_ p: Placement?) -> Rect? { if case .floating(let r) = p { r } else { nil } }
    #expect(w.overview(on: 2) == [
        OverviewItem(id: 5, workspace: 1, frame: tiled(s.placements[5])!),
        OverviewItem(id: 3, workspace: 1, frame: tiled(s.placements[3])!),
        OverviewItem(id: 2, workspace: 1, frame: floated(s.placements[2])!),
        OverviewItem(id: 9, workspace: 3, frame: area2),
    ])
    #expect(w.overview(on: 1) == [OverviewItem(id: 1, workspace: 0, frame: area1)])
}

@Test func overviewActionTogglesOverview() {
    #expect(makeWorld().perform(.overview) == [.toggleOverview])
}

@Test func clipboardActionTogglesClipboard() {
    #expect(makeWorld().perform(.clipboard) == [.toggleClipboard])
}

@Test func rememberedHiddenWindowDoesNotTakeFocus() {
    let w = makeWorld()
    w.remember([WindowMemory(id: 2, app: "Ghostty", workspace: 5)])
    w.addWindow(window(1, on: M2))
    w.addWindow(window(2, on: M2))
    #expect(w.snapshot().focused == 1)
    #expect(w.perform(.killActive) == [.closeWindow(1)])
    _ = w.perform(.workspace(5))
    #expect(w.snapshot().focused == 2)
}

private func workspace(of id: WindowID, in w: World) -> Int? {
    w.memory.first { $0.id == id }?.workspace
}

private func closeOn(_ n: Int, _ id: WindowID, app: String = "Claude", in w: World, at t: Double) {
    w.addWindow(window(id, on: M2, app: app))
    _ = w.perform(.moveToWorkspace(n))
    w.removeWindow(id, closedAt: t)
}

@Test func reopenedWindowReturnsToClosedWorkspace() {
    let w = makeWorld()
    closeOn(3, 1, in: w, at: 10)
    w.addWindow(window(2, on: M2, app: "Claude"), at: 14)
    #expect(workspace(of: 2, in: w) == 3)
}

@Test func reopenAfterTimeoutLandsOnVisibleWorkspace() {
    let w = makeWorld()
    closeOn(3, 1, in: w, at: 10)
    w.addWindow(window(2, on: M2, app: "Claude"), at: 16)
    #expect(workspace(of: 2, in: w) == 1)
}

@Test func reopenedWindowsTakeClosedWorkspacesInOrder() {
    let w = makeWorld()
    closeOn(2, 1, in: w, at: 10)
    closeOn(6, 2, in: w, at: 10.1)
    closeOn(6, 3, in: w, at: 10.2)
    for id: WindowID in 11...14 { w.addWindow(window(id, on: M2, app: "Claude"), at: 11) }
    #expect([11, 12, 13, 14].map { workspace(of: $0, in: w) } == [2, 6, 6, 1])
}

@Test func reopenMatchesOnlySameAppAndAvailableWorkspace() {
    let w = makeWorld()
    closeOn(3, 1, in: w, at: 10)
    w.addWindow(window(2, on: M2, app: "Safari"), at: 11)
    #expect(workspace(of: 2, in: w) == 1)

    let single = makeWorld()
    single.addWindow(window(5, on: M1, app: "Claude"))
    single.removeWindow(5, closedAt: 10)
    single.setMonitors([M1])
    single.addWindow(window(6, on: M1, app: "Claude"), at: 11)
    #expect(workspace(of: 6, in: single) == 1)
}

@Test func reopenedHiddenWindowDoesNotTakeFocus() {
    let w = makeWorld()
    closeOn(3, 1, in: w, at: 10)
    w.addWindow(window(2, on: M2, app: "Ghostty"))
    w.addWindow(window(3, on: M2, app: "Claude"), at: 11)
    #expect(workspace(of: 3, in: w) == 3)
    #expect(w.snapshot().focused == 2)
}

@Test func removalWithoutCloseLeavesNoReopenEntry() {
    let w = makeWorld()
    w.addWindow(window(1, on: M2, app: "Claude"))
    _ = w.perform(.moveToWorkspace(3))
    w.removeWindow(1)
    w.addWindow(window(2, on: M2, app: "Claude"), at: 11)
    #expect(workspace(of: 2, in: w) == 1)
}
