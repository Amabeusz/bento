import Testing
@testable import HyprCore

private let M1 = MonitorInfo(id: 1, frame: Rect(x: 0, y: 0, w: 1512, h: 982), usable: Rect(x: 0, y: 33, w: 1512, h: 949), isBuiltin: true)
private let M2 = MonitorInfo(id: 2, frame: Rect(x: 1512, y: 0, w: 2560, h: 1440), usable: Rect(x: 1512, y: 25, w: 2560, h: 1415), isBuiltin: false)

@Suite struct RecoveryTests {
    @Test func parkFrameIsBottomRightCorner() {
        #expect(parkFrame(for: Rect(x: 10, y: 20, w: 800, h: 600), on: M2, monitors: [M1, M2]) == Rect(x: 4071, y: 1439, w: 800, h: 600))
    }

    @Test func parkFrameAvoidsOtherMonitors() {
        let r = parkFrame(for: Rect(x: 0, y: 0, w: 800, h: 600), on: M1, monitors: [M1, M2])
        #expect(r == Rect(x: -799, y: 981, w: 800, h: 600))
        #expect(r.intersection(M2.frame) == nil)
        #expect(isParked(r, monitors: [M1, M2]))
    }

    @Test func parkedFrameDetected() {
        #expect(isParked(parkFrame(for: Rect(x: 0, y: 0, w: 800, h: 600), on: M2, monitors: [M1, M2]), monitors: [M1, M2]))
        #expect(!isParked(Rect(x: 100, y: 100, w: 800, h: 600), monitors: [M1, M2]))
    }

    @Test func recoveryFrameCentersOnMain() {
        #expect(recoveryFrame(for: Rect(x: 5000, y: 5000, w: 800, h: 600), on: M1) == Rect(x: 356, y: 207.5, w: 800, h: 600))
        #expect(recoveryFrame(for: Rect(x: 0, y: 0, w: 3000, h: 2000), on: M1) == M1.usable)
    }
}
