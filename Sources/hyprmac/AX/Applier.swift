import HyprCore

@MainActor
final class Applier {
    private let tracker: WindowTracker
    private var plan = ApplyPlan()

    init(tracker: WindowTracker) {
        self.tracker = tracker
    }

    func apply(_ s: LayoutSnapshot) {
        for (id, frame) in plan.writes(for: s) {
            tracker.window(id)?.frame = frame
        }
    }
}
