import Testing
@testable import HyprCore

private let screen = Rect(x: 0, y: 0, w: 2560, h: 1440)

private func overlaps(_ a: Rect, _ b: Rect) -> Bool {
    a.x < b.maxX && b.x < a.maxX && a.y < b.maxY && b.y < a.maxY
}

private func inside(_ r: Rect, _ area: Rect) -> Bool {
    r.x >= area.x && r.y >= area.y && r.maxX <= area.maxX && r.maxY <= area.maxY
}

@Suite struct OverviewTests {
    @Test func gridPutsTwoTallWindowsSideBySide() {
        let tall = Rect(x: 0, y: 0, w: 1263, h: 1348)
        let r = overviewGrid(sizes: [tall, tall], in: screen, gap: 20)
        #expect(r.count == 2)
        #expect(r[0].maxX <= r[1].x)
        #expect(r[0].w / tall.w >= 0.9)
        #expect(abs(r[0].w / r[0].h - tall.w / tall.h) < 0.01)
    }

    @Test func gridKeepsEveryWindowInsideWithoutOverlap() {
        let sizes = [
            Rect(x: 0, y: 0, w: 2536, h: 1348), Rect(x: 0, y: 0, w: 1263, h: 1348), Rect(x: 0, y: 0, w: 640, h: 400),
            Rect(x: 0, y: 0, w: 1263, h: 662), Rect(x: 0, y: 0, w: 1263, h: 662), Rect(x: 0, y: 0, w: 2536, h: 1348),
        ]
        let area = Rect(x: 2560, y: 100, w: 1512, h: 882)
        let r = overviewGrid(sizes: sizes, in: area, gap: 20)
        #expect(r.count == sizes.count)
        for (i, a) in r.enumerated() {
            #expect(inside(a, area))
            #expect(abs(a.w / a.h - sizes[i].w / sizes[i].h) < 0.01)
            for b in r[(i + 1)...] { #expect(!overlaps(a, b)) }
        }
    }

    @Test func gridPicksColumnsGivingLargestThumbnails() {
        let wide = Rect(x: 0, y: 0, w: 2536, h: 1348)
        let r = overviewGrid(sizes: [wide, wide], in: screen, gap: 20)
        #expect(r[0].maxY <= r[1].y)
        #expect(r[0].w > 1290)
    }

    @Test func gridNeverEnlargesSmallWindows() {
        let small = Rect(x: 0, y: 0, w: 400, h: 300)
        let r = overviewGrid(sizes: [small], in: screen, gap: 20)
        #expect(r[0].w == 400 && r[0].h == 300)
    }

    @Test func gridOfNothingIsEmpty() {
        #expect(overviewGrid(sizes: [], in: screen, gap: 20) == [])
    }

    @Test func neighborIsNearestThumbnailInThatDirection() {
        let r = [
            Rect(x: 0, y: 0, w: 100, h: 100), Rect(x: 200, y: 0, w: 100, h: 100), Rect(x: 400, y: 0, w: 100, h: 100),
            Rect(x: 200, y: 200, w: 100, h: 100), Rect(x: 3000, y: 50, w: 100, h: 100),
        ]
        #expect(overviewNeighbor(from: 1, in: r, toward: .right) == 2)
        #expect(overviewNeighbor(from: 1, in: r, toward: .left) == 0)
        #expect(overviewNeighbor(from: 1, in: r, toward: .down) == 3)
        #expect(overviewNeighbor(from: 3, in: r, toward: .up) == 1)
        #expect(overviewNeighbor(from: 2, in: r, toward: .right) == 4)
        #expect(overviewNeighbor(from: 0, in: r, toward: .left) == nil)
        #expect(overviewNeighbor(from: 1, in: r, toward: .up) == nil)
    }

    @Test func gridLeavesRoomForLabelAboveEachThumbnail() {
        let sizes = [Rect(x: 0, y: 0, w: 2536, h: 1348), Rect(x: 0, y: 0, w: 2536, h: 1348), Rect(x: 0, y: 0, w: 1263, h: 1348)]
        let area = Rect(x: 0, y: 100, w: 1512, h: 882)
        let r = overviewGrid(sizes: sizes, in: area, gap: 20, label: 28)
        for (i, a) in r.enumerated() {
            let label = Rect(x: a.x, y: a.y - 28, w: a.w, h: 28)
            #expect(inside(label, area))
            for (j, b) in r.enumerated() where j != i { #expect(!overlaps(label, b)) }
        }
        #expect(overviewGrid(sizes: sizes, in: area, gap: 20, label: 0) == overviewGrid(sizes: sizes, in: area, gap: 20))
        let tall = overviewGrid(sizes: [Rect(x: 0, y: 0, w: 1263, h: 1348)], in: area, gap: 0, label: 28)[0]
        #expect(tall.y - 28 >= area.y && tall.maxY <= area.maxY)
    }

    @Test func neighborIgnoresCloserThumbnailOffTheDiagonal() {
        let r = [Rect(x: 0, y: 0, w: 100, h: 100), Rect(x: 150, y: 300, w: 100, h: 100), Rect(x: 400, y: 0, w: 100, h: 100)]
        #expect(overviewNeighbor(from: 0, in: r, toward: .right) == 2)
    }
}
