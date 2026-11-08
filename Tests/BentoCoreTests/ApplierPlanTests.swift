import Testing
@testable import BentoCore

private func snapshot(_ placements: [WindowID: Placement]) -> LayoutSnapshot {
    LayoutSnapshot(placements: placements, focused: nil, bars: [:], visibleWorkspace: [:])
}

private let A = Rect(x: 12, y: 50, w: 700, h: 900)
private let B = Rect(x: 722, y: 50, w: 700, h: 900)
private let P = Rect(x: 1511, y: 981, w: 700, h: 900)

@Suite struct ApplierPlanTests {
    @Test func firstSnapshotWritesAll() {
        var plan = ApplyPlan()
        #expect(plan.writes(for: snapshot([1: .tiled(A), 2: .floating(B), 3: .parked(P)])) == [1: A, 2: B, 3: P])
    }

    @Test func doesNotReapplyUnchangedTargets() {
        var plan = ApplyPlan()
        let s = snapshot([1: .tiled(A), 2: .floating(B)])
        _ = plan.writes(for: s)
        #expect(plan.writes(for: s) == [:])
    }

    @Test func changedTargetIsWritten() {
        var plan = ApplyPlan()
        _ = plan.writes(for: snapshot([1: .tiled(A), 2: .tiled(B)]))
        #expect(plan.writes(for: snapshot([1: .parked(P), 2: .tiled(B)])) == [1: P])
    }

    @Test func forgetsWindowsNoLongerInSnapshot() {
        var plan = ApplyPlan()
        _ = plan.writes(for: snapshot([1: .tiled(A)]))
        _ = plan.writes(for: snapshot([:]))
        #expect(plan.writes(for: snapshot([1: .tiled(A)])) == [1: A])
    }

    @Test func invalidatedWindowIsWrittenAgain() {
        var plan = ApplyPlan()
        let s = snapshot([1: .tiled(A), 2: .tiled(B)])
        _ = plan.writes(for: s)
        plan.invalidate(1)
        #expect(plan.writes(for: s) == [1: A])
    }
}
