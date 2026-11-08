import Testing
@testable import BentoCore

private let A = Rect(x: 0, y: 0, w: 1000, h: 600)

private func tree(_ ids: [WindowID]) -> DwindleTree {
    var t = DwindleTree()
    var previous: WindowID?
    for id in ids {
        t.insert(id, splitting: previous, area: A, gapsIn: 10)
        previous = id
    }
    return t
}

@Suite struct DwindleTreeTests {
    @Test func singleFillsArea() {
        var t = DwindleTree()
        t.insert(1, splitting: nil, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10) == [1: A])
    }

    @Test func secondSplitsSideBySide() {
        let t = tree([1, 2])
        #expect(t.frames(in: A, gapsIn: 10) == [1: Rect(x: 0, y: 0, w: 495, h: 600), 2: Rect(x: 505, y: 0, w: 495, h: 600)])
    }

    @Test func thirdStacksUnderSecond() {
        let t = tree([1, 2, 3])
        #expect(t.frames(in: A, gapsIn: 10)[3] == Rect(x: 505, y: 305, w: 495, h: 295))
    }

    @Test func removeGivesSpaceToSibling() {
        var t = tree([1, 2])
        t.remove(2)
        #expect(t.frames(in: A, gapsIn: 10) == [1: A])
    }

    @Test func removeLastWindowEmptiesTree() {
        var t = tree([1])
        t.remove(1)
        #expect(t.windows.isEmpty)
        #expect(t.frames(in: A, gapsIn: 10) == [:])
    }

    @Test func toggleSplitStacks() {
        var t = tree([1, 2])
        t.toggleSplit(of: 2)
        #expect(t.frames(in: A, gapsIn: 10) == [1: Rect(x: 0, y: 0, w: 1000, h: 295), 2: Rect(x: 0, y: 305, w: 1000, h: 295)])
    }

    @Test func resizeGrowsAndClamps() {
        var t = tree([1, 2])
        t.resize(1, dx: 100, dy: 0, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10)[1]?.w == 595)
        t.resize(1, dx: 10_000, dy: 0, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10)[1]?.w == 895)
        t.resize(1, dx: -10_000, dy: 0, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10)[1]?.w == 95)
    }

    @Test func resizeGrowsSecondChildWithPositiveDelta() {
        var t = tree([1, 2])
        t.resize(2, dx: 100, dy: 0, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10)[2]?.w == 595)
    }

    @Test func resizeUsesNearestAncestorOfEachOrientation() {
        var t = tree([1, 2, 3])
        t.resize(3, dx: 100, dy: 60, area: A, gapsIn: 10)
        let f = t.frames(in: A, gapsIn: 10)
        #expect(f[3] == Rect(x: 405, y: 245, w: 595, h: 355))
        #expect(f[2] == Rect(x: 405, y: 0, w: 595, h: 235))
        #expect(f[1] == Rect(x: 0, y: 0, w: 395, h: 600))
    }

    @Test func resizeIgnoresAxisWithoutAncestor() {
        var t = tree([1, 2])
        t.resize(1, dx: 0, dy: 100, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10) == tree([1, 2]).frames(in: A, gapsIn: 10))
    }

    @Test func swapExchangesPositions() {
        var t = tree([1, 2])
        t.swap(1, 2)
        let f = t.frames(in: A, gapsIn: 10)
        #expect(f[2]?.x == 0)
        #expect(f[1]?.x == 505)
    }

    @Test func swapWithMissingIdIsNoOp() {
        var t = tree([1, 2])
        t.swap(1, 99)
        #expect(t.windows == [1, 2])
    }

    @Test func neighborRightAndNone() {
        let t = tree([1, 2, 3])
        #expect(t.neighbor(of: 1, .right, area: A, gapsIn: 10) == 2)
        #expect(t.neighbor(of: 2, .down, area: A, gapsIn: 10) == 3)
        #expect(t.neighbor(of: 3, .up, area: A, gapsIn: 10) == 2)
        #expect(t.neighbor(of: 3, .left, area: A, gapsIn: 10) == 1)
        #expect(t.neighbor(of: 1, .left, area: A, gapsIn: 10) == nil)
    }

    @Test func insertWithMissingTargetUsesLast() {
        var t = tree([1, 2])
        t.insert(3, splitting: 99, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10) == tree([1, 2, 3]).frames(in: A, gapsIn: 10))
    }

    @Test func insertWithNilTargetUsesLast() {
        var t = tree([1, 2])
        t.insert(3, splitting: nil, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10) == tree([1, 2, 3]).frames(in: A, gapsIn: 10))
    }

    @Test func windowsAreInOrder() {
        var t = tree([1, 2, 3])
        t.insert(4, splitting: 1, area: A, gapsIn: 10)
        #expect(t.windows == [1, 4, 2, 3])
        #expect(t.contains(4))
        #expect(!t.contains(99))
    }

    @Test func missingIdOperationsAreNoOps() {
        var t = tree([1, 2])
        t.remove(99)
        t.toggleSplit(of: 99)
        t.resize(99, dx: 100, dy: 100, area: A, gapsIn: 10)
        #expect(t.frames(in: A, gapsIn: 10) == tree([1, 2]).frames(in: A, gapsIn: 10))
    }
}

@Test func replaceKeepsTheTileSlot() {
    let a = Rect(x: 0, y: 0, w: 1000, h: 600)
    var t = DwindleTree()
    t.insert(1, splitting: nil, area: a, gapsIn: 10)
    t.insert(2, splitting: 1, area: a, gapsIn: 10)
    let before = t.frames(in: a, gapsIn: 10)
    t.replace(2, with: 3)
    #expect(t.frames(in: a, gapsIn: 10) == [1: before[1]!, 3: before[2]!])
}
