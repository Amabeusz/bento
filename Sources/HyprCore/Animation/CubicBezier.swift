public extension CubicBezierSpec {
    func progress(at t: Double) -> Double {
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        return Self.coordinate(solve(x: t), y1, y2)
    }

    private func solve(x: Double) -> Double {
        var s = x
        for _ in 0..<8 {
            let error = Self.coordinate(s, x1, x2) - x
            if abs(error) < 1e-7 { return s }
            let slope = Self.slope(s, x1, x2)
            if abs(slope) < 1e-6 { break }
            s -= error / slope
        }
        var low = 0.0
        var high = 1.0
        s = x
        for _ in 0..<50 {
            let value = Self.coordinate(s, x1, x2)
            if abs(value - x) < 1e-7 { break }
            if value < x { low = s } else { high = s }
            s = (low + high) / 2
        }
        return s
    }

    private static func coordinate(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * s * p1 + 3 * inverse * s * s * p2 + s * s * s
    }

    private static func slope(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let inverse = 1 - s
        return 3 * inverse * inverse * p1 + 6 * inverse * s * (p2 - p1) + 3 * s * s * (1 - p2)
    }
}
