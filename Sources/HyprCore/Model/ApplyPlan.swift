public struct ApplyPlan {
    private var written: [WindowID: Rect] = [:]

    public init() {}

    public mutating func writes(for snapshot: LayoutSnapshot) -> [WindowID: Rect] {
        var targets: [WindowID: Rect] = [:]
        for (id, placement) in snapshot.placements {
            switch placement {
            case .tiled(let r), .floating(let r), .parked(let r): targets[id] = r
            }
        }
        let changed = targets.filter { written[$0.key] != $0.value }
        written = targets
        return changed
    }
}
