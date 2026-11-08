public struct TabCandidate: Equatable, Sendable {
    public var id: WindowID
    public var pid: Int32
    public var frame: Rect

    public init(id: WindowID, pid: Int32, frame: Rect) {
        self.id = id
        self.pid = pid
        self.frame = frame
    }
}

public struct TabSwap: Equatable, Sendable {
    public var old: WindowID
    public var new: WindowID

    public init(old: WindowID, new: WindowID) {
        self.old = old
        self.new = new
    }
}

public func pairTabSwaps(lost: [TabCandidate], gained: [TabCandidate]) -> [TabSwap] {
    var free = gained
    return lost.compactMap { old in
        guard let i = free.firstIndex(where: { $0.pid == old.pid && sameFrame($0.frame, old.frame) }) else { return nil }
        return TabSwap(old: old.id, new: free.remove(at: i).id)
    }
}

public func isHiddenTab(_ w: TabCandidate, onScreen: Bool, shown: [TabCandidate]) -> Bool {
    !onScreen && shown.contains { $0.id != w.id && $0.pid == w.pid && sameFrame($0.frame, w.frame) }
}

private func sameFrame(_ a: Rect, _ b: Rect) -> Bool {
    abs(a.x - b.x) <= 2 && abs(a.y - b.y) <= 2 && abs(a.w - b.w) <= 2 && abs(a.h - b.h) <= 2
}
