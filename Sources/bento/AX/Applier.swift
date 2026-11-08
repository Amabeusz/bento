import BentoCore

@MainActor
final class Applier {
    private let tracker: WindowTracker
    private var plan = ApplyPlan()
    private var lastWrite: [WindowID: ContinuousClock.Instant] = [:]
    private var snapBack = SnapBack()

    init(tracker: WindowTracker) {
        self.tracker = tracker
    }

    func apply(_ s: LayoutSnapshot) {
        for (id, frame) in plan.writes(for: s) {
            place(id, frame)
        }
    }

    func place(_ id: WindowID, _ frame: Rect) {
        tracker.window(id)?.frame = frame
        lastWrite[id] = .now
    }

    func wroteRecently(_ id: WindowID) -> Bool {
        lastWrite[id].map { ContinuousClock.now - $0 < .milliseconds(300) } ?? false
    }

    func needsRestore(_ id: WindowID, frame: Rect, target: Rect) -> Bool {
        snapBack.needsRestore(id, frame: frame, target: target)
    }

    func restore(_ id: WindowID, to target: Rect, in s: LayoutSnapshot) {
        plan.invalidate(id)
        apply(s)
        if let frame = tracker.window(id)?.frame { snapBack.settle(id, target: target, at: frame) }
    }
}
