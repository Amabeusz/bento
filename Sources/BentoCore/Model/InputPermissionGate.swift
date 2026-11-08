public enum PermissionChange: Equatable, Sendable {
    case lost, regained
}

public struct InputPermissionGate: Sendable {
    public private(set) var allowed = true

    public init() {}

    public mutating func update(accessibility: Bool, postEvent: Bool) -> PermissionChange? {
        let now = accessibility && postEvent
        defer { allowed = now }
        guard now != allowed else { return nil }
        return now ? .regained : .lost
    }
}
