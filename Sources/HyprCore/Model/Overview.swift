public struct OverviewItem: Equatable, Sendable {
    public var id: WindowID
    public var workspace: Int
    public var frame: Rect

    public init(id: WindowID, workspace: Int, frame: Rect) {
        self.id = id
        self.workspace = workspace
        self.frame = frame
    }
}

public func overviewGrid(sizes: [Rect], in area: Rect, gap: Double, label: Double = 0) -> [Rect] {
    guard !sizes.isEmpty else { return [] }
    func cell(_ columns: Int) -> (w: Double, h: Double) {
        let rows = (sizes.count + columns - 1) / columns
        return (max(0, (area.w - gap * Double(columns + 1)) / Double(columns)),
                max(0, (area.h - gap * Double(rows + 1)) / Double(rows) - label))
    }
    func scale(_ size: Rect, _ c: (w: Double, h: Double)) -> Double {
        min(c.w / size.w, c.h / size.h, 1)
    }
    let columns = (1...sizes.count).max { a, b in
        let ca = cell(a), cb = cell(b)
        return sizes.map { scale($0, ca) }.min()! < sizes.map { scale($0, cb) }.min()!
    }!
    let c = cell(columns)
    let rows = (sizes.count + columns - 1) / columns
    let top = area.y + (area.h - Double(rows) * (c.h + label) - Double(rows - 1) * gap) / 2
    return sizes.enumerated().map { i, size in
        let row = i / columns
        let inRow = min(columns, sizes.count - row * columns)
        let left = area.x + (area.w - Double(inRow) * c.w - Double(inRow - 1) * gap) / 2
        let s = scale(size, c)
        let w = size.w * s, h = size.h * s
        return Rect(x: left + Double(i % columns) * (c.w + gap) + (c.w - w) / 2,
                    y: top + Double(row) * (c.h + label + gap) + label + (c.h - h) / 2, w: w, h: h)
    }
}

public func overviewNeighbor(from index: Int, in rects: [Rect], toward dir: Direction) -> Int? {
    let c = rects[index].center
    func distance(_ r: Rect) -> Double {
        (r.center.x - c.x) * (r.center.x - c.x) + (r.center.y - c.y) * (r.center.y - c.y)
    }
    return rects.indices.filter { i in
        let dx = rects[i].center.x - c.x
        let dy = rects[i].center.y - c.y
        switch dir {
        case .left: return -dx > abs(dy)
        case .right: return dx > abs(dy)
        case .up: return -dy > abs(dx)
        case .down: return dy > abs(dx)
        }
    }.min { distance(rects[$0]) < distance(rects[$1]) }
}
