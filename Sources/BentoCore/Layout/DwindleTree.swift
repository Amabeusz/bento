public typealias WindowID = UInt32

public struct DwindleTree: Sendable {
    private enum Node: Sendable {
        case leaf(WindowID)
        indirect case split(horizontal: Bool, ratio: Double, first: Node, second: Node)

        func contains(_ id: WindowID) -> Bool {
            switch self {
            case .leaf(let w): w == id
            case .split(_, _, let a, let b): a.contains(id) || b.contains(id)
            }
        }

        var windows: [WindowID] {
            switch self {
            case .leaf(let w): [w]
            case .split(_, _, let a, let b): a.windows + b.windows
            }
        }
    }

    private var root: Node?

    public init() {}

    public var windows: [WindowID] { root?.windows ?? [] }

    public func contains(_ id: WindowID) -> Bool { root?.contains(id) ?? false }

    public mutating func insert(_ id: WindowID, splitting target: WindowID?, area: Rect, gapsIn: Double) {
        guard let current = root else {
            root = .leaf(id)
            return
        }
        let resolved = target.flatMap { contains($0) ? $0 : nil } ?? windows.last!
        let box = frames(in: area, gapsIn: gapsIn)[resolved] ?? area
        root = Self.splitting(current, resolved, with: id, horizontal: box.w >= box.h)
    }

    public mutating func replace(_ old: WindowID, with new: WindowID) {
        guard let root, contains(old), !contains(new) else { return }
        self.root = Self.swapping(root, old, new)
    }

    public mutating func remove(_ id: WindowID) {
        guard let current = root else { return }
        root = Self.removing(current, id)
    }

    public func frames(in area: Rect, gapsIn: Double) -> [WindowID: Rect] {
        var result: [WindowID: Rect] = [:]
        if let root { Self.layout(root, area, gapsIn, &result) }
        return result
    }

    public mutating func toggleSplit(of id: WindowID) {
        guard let current = root else { return }
        root = Self.toggling(current, id)
    }

    public mutating func resize(_ id: WindowID, dx: Double, dy: Double, area: Rect, gapsIn: Double) {
        guard let current = root else { return }
        var pendingDx: Double? = dx
        var pendingDy: Double? = dy
        root = Self.resizing(current, id, area, gapsIn, &pendingDx, &pendingDy)
    }

    public mutating func swap(_ a: WindowID, _ b: WindowID) {
        guard let current = root, contains(a), contains(b) else { return }
        root = Self.swapping(current, a, b)
    }

    public func neighbor(of id: WindowID, _ dir: Direction, area: Rect, gapsIn: Double) -> WindowID? {
        let all = frames(in: area, gapsIn: gapsIn)
        guard let from = all[id] else { return nil }
        var best: (id: WindowID, distance: Double, overlap: Double)?
        for other in windows where other != id {
            guard let f = all[other] else { continue }
            let distance: Double
            let overlap: Double
            switch dir {
            case .right:
                distance = f.minX - from.maxX
                overlap = min(from.maxY, f.maxY) - max(from.minY, f.minY)
            case .left:
                distance = from.minX - f.maxX
                overlap = min(from.maxY, f.maxY) - max(from.minY, f.minY)
            case .down:
                distance = f.minY - from.maxY
                overlap = min(from.maxX, f.maxX) - max(from.minX, f.minX)
            case .up:
                distance = from.minY - f.maxY
                overlap = min(from.maxX, f.maxX) - max(from.minX, f.minX)
            }
            guard distance >= 0 else { continue }
            if let b = best, distance > b.distance || (distance == b.distance && overlap <= b.overlap) { continue }
            best = (other, distance, overlap)
        }
        return best?.id
    }

    private static func clamp(_ ratio: Double) -> Double { min(0.9, max(0.1, ratio)) }

    private static func children(of rect: Rect, horizontal: Bool, ratio: Double, gap: Double) -> (Rect, Rect) {
        if horizontal {
            let left = rect.w * ratio
            return (
                Rect(x: rect.x, y: rect.y, w: left - gap / 2, h: rect.h),
                Rect(x: rect.x + left + gap / 2, y: rect.y, w: rect.w - left - gap / 2, h: rect.h)
            )
        }
        let top = rect.h * ratio
        return (
            Rect(x: rect.x, y: rect.y, w: rect.w, h: top - gap / 2),
            Rect(x: rect.x, y: rect.y + top + gap / 2, w: rect.w, h: rect.h - top - gap / 2)
        )
    }

    private static func layout(_ node: Node, _ rect: Rect, _ gap: Double, _ out: inout [WindowID: Rect]) {
        switch node {
        case .leaf(let w):
            out[w] = rect
        case .split(let horizontal, let ratio, let a, let b):
            let (ra, rb) = children(of: rect, horizontal: horizontal, ratio: ratio, gap: gap)
            layout(a, ra, gap, &out)
            layout(b, rb, gap, &out)
        }
    }

    private static func splitting(_ node: Node, _ target: WindowID, with id: WindowID, horizontal: Bool) -> Node {
        switch node {
        case .leaf(let w):
            guard w == target else { return node }
            return .split(horizontal: horizontal, ratio: 0.5, first: node, second: .leaf(id))
        case .split(let h, let r, let a, let b):
            return .split(
                horizontal: h, ratio: r,
                first: splitting(a, target, with: id, horizontal: horizontal),
                second: splitting(b, target, with: id, horizontal: horizontal)
            )
        }
    }

    private static func removing(_ node: Node, _ id: WindowID) -> Node? {
        switch node {
        case .leaf(let w):
            return w == id ? nil : node
        case .split(let h, let r, let a, let b):
            guard let na = removing(a, id) else { return b }
            guard let nb = removing(b, id) else { return a }
            return .split(horizontal: h, ratio: r, first: na, second: nb)
        }
    }

    private static func toggling(_ node: Node, _ id: WindowID) -> Node {
        guard case .split(let h, let r, let a, let b) = node else { return node }
        if case .leaf(let w) = a, w == id { return .split(horizontal: !h, ratio: r, first: a, second: b) }
        if case .leaf(let w) = b, w == id { return .split(horizontal: !h, ratio: r, first: a, second: b) }
        return .split(horizontal: h, ratio: r, first: toggling(a, id), second: toggling(b, id))
    }

    private static func resizing(
        _ node: Node, _ id: WindowID, _ rect: Rect, _ gap: Double,
        _ dx: inout Double?, _ dy: inout Double?
    ) -> Node {
        guard case .split(let h, var r, let a, let b) = node, node.contains(id) else { return node }
        let (ra, rb) = children(of: rect, horizontal: h, ratio: r, gap: gap)
        let inFirst = a.contains(id)
        let na = inFirst ? resizing(a, id, ra, gap, &dx, &dy) : a
        let nb = inFirst ? b : resizing(b, id, rb, gap, &dx, &dy)
        if h, let d = dx {
            r = clamp(r + (inFirst ? d : -d) / rect.w)
            dx = nil
        } else if !h, let d = dy {
            r = clamp(r + (inFirst ? d : -d) / rect.h)
            dy = nil
        }
        return .split(horizontal: h, ratio: r, first: na, second: nb)
    }

    private static func swapping(_ node: Node, _ a: WindowID, _ b: WindowID) -> Node {
        switch node {
        case .leaf(let w):
            if w == a { return .leaf(b) }
            if w == b { return .leaf(a) }
            return node
        case .split(let h, let r, let first, let second):
            return .split(horizontal: h, ratio: r, first: swapping(first, a, b), second: swapping(second, a, b))
        }
    }
}
