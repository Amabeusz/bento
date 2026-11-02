import Testing
@testable import HyprCore

@Suite struct CubicBezierTests {
    @Test func linearIsIdentity() throws {
        let linear = try #require(Config().beziers["linear"])
        #expect(abs(linear.progress(at: 0.3) - 0.3) < 1e-6)
    }

    @Test func endpoints() throws {
        let smooth = try #require(Config().beziers["smooth"])
        #expect(smooth.progress(at: 0) == 0)
        #expect(smooth.progress(at: 1) == 1)
    }

    @Test func smoothOvershoots() throws {
        let smooth = try #require(Config().beziers["smooth"])
        let samples = stride(from: 0.6, through: 0.95, by: 0.01).map { smooth.progress(at: $0) }
        #expect(samples.contains { $0 > 1.0 })
    }

    @Test func defaultIsMonotonic() throws {
        let curve = try #require(Config().beziers["default"])
        var previous = curve.progress(at: 0)
        for i in 1...100 {
            let value = curve.progress(at: Double(i) / 100)
            #expect(value >= previous)
            previous = value
        }
    }
}
