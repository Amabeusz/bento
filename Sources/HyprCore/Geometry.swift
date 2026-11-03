public struct Point: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Insets: Equatable, Sendable {
    public var top: Double
    public var right: Double
    public var bottom: Double
    public var left: Double

    public init(top: Double, right: Double, bottom: Double, left: Double) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public init(all d: Double) {
        self.init(top: d, right: d, bottom: d, left: d)
    }
}

public struct Rect: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var center: Point { Point(x: x + w / 2, y: y + h / 2) }

    public func inset(by d: Double) -> Rect {
        Rect(x: x + d, y: y + d, w: w - 2 * d, h: h - 2 * d)
    }

    public func inset(by i: Insets) -> Rect {
        Rect(x: x + i.left, y: y + i.top, w: w - i.left - i.right, h: h - i.top - i.bottom)
    }

    public func intersection(_ o: Rect) -> Rect? {
        let left = max(minX, o.minX)
        let top = max(minY, o.minY)
        let right = min(maxX, o.maxX)
        let bottom = min(maxY, o.maxY)
        guard right > left, bottom > top else { return nil }
        return Rect(x: left, y: top, w: right - left, h: bottom - top)
    }

    public func contains(_ p: Point) -> Bool {
        p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY
    }
}
