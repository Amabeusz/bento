import Testing
@testable import HyprCore

private let frame = Rect(x: 1285, y: 759, w: 1263, h: 669)

@Test func tabSwitchPairsHiddenAndShownTabOfSameApp() {
    let lost = [TabCandidate(id: 1, pid: 10, frame: frame)]
    let gained = [TabCandidate(id: 2, pid: 10, frame: Rect(x: 1285.5, y: 759, w: 1263, h: 669))]
    #expect(pairTabSwaps(lost: lost, gained: gained) == [TabSwap(old: 1, new: 2)])
}

@Test func differentAppOrFrameIsNotATabSwap() {
    let lost = [TabCandidate(id: 1, pid: 10, frame: frame)]
    #expect(pairTabSwaps(lost: lost, gained: [TabCandidate(id: 2, pid: 11, frame: frame)]) == [])
    #expect(pairTabSwaps(lost: lost, gained: [TabCandidate(id: 2, pid: 10, frame: Rect(x: 0, y: 0, w: 500, h: 400))]) == [])
}

@Test func eachTabIsPairedOnce() {
    let lost = [TabCandidate(id: 1, pid: 10, frame: frame), TabCandidate(id: 4, pid: 10, frame: frame)]
    let gained = [TabCandidate(id: 2, pid: 10, frame: frame)]
    #expect(pairTabSwaps(lost: lost, gained: gained) == [TabSwap(old: 1, new: 2)])
}

@Test func newTabTakesTheTileOfTheTabItHides() {
    var config = try! parseConfig(defaultConfigText)
    config.barEnabled = false
    let w = World(config: config)
    let m = MonitorInfo(id: 1, frame: Rect(x: 0, y: 0, w: 1512, h: 982), usable: Rect(x: 0, y: 33, w: 1512, h: 949), isBuiltin: true)
    w.setMonitors([m])
    let win = { (id: WindowID) in WindowInfo(id: id, app: "Ghostty", title: "", isDialog: false, frame: Rect(x: 100, y: 100, w: 400, h: 300)) }
    w.addWindow(win(1))
    w.addWindow(win(2))
    let before = w.snapshot().placements[2]
    w.replaceWindow(2, with: win(3))
    let s = w.snapshot()
    #expect(s.placements[3] == before)
    #expect(s.placements[2] == nil)
    #expect(s.focused == 3)
    #expect(s.placements.count == 2)
}

@Test func offscreenWindowWithShownSiblingIsAHiddenTab() {
    let tab = TabCandidate(id: 1, pid: 10, frame: frame)
    #expect(isHiddenTab(tab, onScreen: false, shown: [TabCandidate(id: 2, pid: 10, frame: frame)]))
}

@Test func offscreenWindowWithoutShownSiblingIsNotAHiddenTab() {
    let w = TabCandidate(id: 1, pid: 10, frame: frame)
    #expect(!isHiddenTab(w, onScreen: false, shown: []))
    #expect(!isHiddenTab(w, onScreen: false, shown: [TabCandidate(id: 2, pid: 11, frame: frame)]))
    #expect(!isHiddenTab(w, onScreen: false, shown: [TabCandidate(id: 2, pid: 10, frame: Rect(x: 0, y: 0, w: 300, h: 200))]))
}

@Test func shownWindowIsNotAHiddenTab() {
    let w = TabCandidate(id: 1, pid: 10, frame: frame)
    #expect(!isHiddenTab(w, onScreen: true, shown: [TabCandidate(id: 2, pid: 10, frame: frame)]))
}
