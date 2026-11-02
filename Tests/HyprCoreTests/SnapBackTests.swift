import Testing
@testable import HyprCore

private let tile = Rect(x: 762, y: 364.5, w: 739, h: 364.5)
private let rounded = Rect(x: 762, y: 365, w: 739, h: 364)
private let dragged = Rect(x: 300, y: 200, w: 739, h: 364.5)
private let draggedAgain = Rect(x: 500, y: 100, w: 739, h: 364.5)

@Suite struct SnapBackTests {
    @Test func windowAwayFromTileNeedsRestore() {
        #expect(SnapBack().needsRestore(1, frame: dragged, target: tile))
    }

    @Test func roundingOnlyDifferenceNeedsNoRestore() {
        #expect(!SnapBack().needsRestore(1, frame: rounded, target: tile))
    }

    @Test func frameAcceptedAfterRestoreIsLeftAlone() {
        var snap = SnapBack()
        let minSized = Rect(x: 762, y: 364.5, w: 900, h: 500)
        snap.settle(1, target: tile, at: minSized)
        #expect(!snap.needsRestore(1, frame: minSized, target: tile))
    }

    @Test func draggingAgainAfterSettlingRestoresAgain() {
        var snap = SnapBack()
        snap.settle(1, target: tile, at: rounded)
        #expect(snap.needsRestore(1, frame: dragged, target: tile))
        snap.settle(1, target: tile, at: rounded)
        #expect(snap.needsRestore(1, frame: draggedAgain, target: tile))
    }

    @Test func acceptedFrameOfOldTargetDoesNotApplyToNewTarget() {
        var snap = SnapBack()
        let minSized = Rect(x: 762, y: 364.5, w: 900, h: 500)
        snap.settle(1, target: tile, at: minSized)
        #expect(snap.needsRestore(1, frame: minSized, target: Rect(x: 12, y: 50, w: 739, h: 729)))
    }

    @Test func acceptedFrameIsPerWindow() {
        var snap = SnapBack()
        snap.settle(1, target: tile, at: dragged)
        #expect(snap.needsRestore(2, frame: dragged, target: tile))
    }
}
