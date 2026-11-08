public func isManagedWindowLayer(_ layer: Int) -> Bool {
    layer < 101
}

public let windowSettleTime = 0.1

public func isSettled(windowAges: [Double]) -> Bool {
    windowAges.allSatisfy { $0 >= windowSettleTime }
}
