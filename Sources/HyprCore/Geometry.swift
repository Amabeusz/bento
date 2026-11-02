public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double
}

public struct Rect: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + w }
    var maxY: Double { y + h }
    var center: Point { Point(x: x + w / 2, y: y + h / 2) }

    func inset(by d: Double) -> Rect {
        Rect(x: x + d, y: y + d, w: w - 2 * d, h: h - 2 * d)
    }

    func intersection(_ o: Rect) -> Rect? {
        let left = max(minX, o.minX)
        let top = max(minY, o.minY)
        let right = min(maxX, o.maxX)
        let bottom = min(maxY, o.maxY)
        guard right > left, bottom > top else { return nil }
        return Rect(x: left, y: top, w: right - left, h: bottom - top)
    }

    func contains(_ p: Point) -> Bool {
        p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY
    }
}
