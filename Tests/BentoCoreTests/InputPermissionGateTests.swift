import Testing
@testable import BentoCore

@Suite struct InputPermissionGateTests {
    @Test func losingPostEventStopsInput() {
        var gate = InputPermissionGate()
        #expect(gate.update(accessibility: true, postEvent: false) == .lost)
        #expect(!gate.allowed)
    }

    @Test func losingAccessibilityStopsInput() {
        var gate = InputPermissionGate()
        #expect(gate.update(accessibility: false, postEvent: true) == .lost)
    }

    @Test func lossIsReportedOnce() {
        var gate = InputPermissionGate()
        _ = gate.update(accessibility: true, postEvent: false)
        #expect(gate.update(accessibility: false, postEvent: false) == nil)
    }

    @Test func regainingBothRestoresInput() {
        var gate = InputPermissionGate()
        _ = gate.update(accessibility: false, postEvent: false)
        #expect(gate.update(accessibility: true, postEvent: false) == nil)
        #expect(gate.update(accessibility: true, postEvent: true) == .regained)
        #expect(gate.allowed)
    }

    @Test func unchangedPermissionsReportNothing() {
        var gate = InputPermissionGate()
        #expect(gate.update(accessibility: true, postEvent: true) == nil)
    }
}
