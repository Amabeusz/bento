import HyprCore

@MainActor
final class Applier {
    private let tracker: WindowTracker
    private var plan = ApplyPlan()
    private var lastWrite: [WindowID: ContinuousClock.Instant] = [:]
    private var refused: [WindowID: Rect] = [:]

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

    func restore(_ id: WindowID, to target: Rect, in s: LayoutSnapshot) {
        guard refused[id] != target else { return }
        plan.invalidate(id)
        apply(s)
        if tracker.window(id)?.frame != target { refused[id] = target }
    }
}
