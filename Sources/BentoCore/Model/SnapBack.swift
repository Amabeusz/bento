public struct SnapBack {
    private var settled: [WindowID: (target: Rect, frame: Rect)] = [:]

    public init() {}

    public func needsRestore(_ id: WindowID, frame: Rect, target: Rect) -> Bool {
        guard !close(frame, target) else { return false }
        guard let s = settled[id], s.target == target else { return true }
        return !close(frame, s.frame)
    }

    public mutating func settle(_ id: WindowID, target: Rect, at frame: Rect) {
        settled[id] = (target, frame)
    }

    private func close(_ a: Rect, _ b: Rect) -> Bool {
        abs(a.x - b.x) <= 1 && abs(a.y - b.y) <= 1 && abs(a.w - b.w) <= 1 && abs(a.h - b.h) <= 1
    }
}
