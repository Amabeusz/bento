public func parkFrame(for size: Rect, on monitor: MonitorInfo, monitors: [MonitorInfo]) -> Rect {
    let f = monitor.frame
    let left = f.minX - size.w + 1
    let top = f.minY - size.h + 1
    let corners = [(f.maxX - 1, f.maxY - 1), (left, f.maxY - 1), (f.maxX - 1, top), (left, top)]
        .map { Rect(x: $0.0, y: $0.1, w: size.w, h: size.h) }
    let others = monitors.filter { $0.id != monitor.id }
    return corners.first { r in others.allSatisfy { r.intersection($0.frame) == nil } } ?? corners[0]
}

public func isParked(_ frame: Rect, monitors: [MonitorInfo]) -> Bool {
    let visible = monitors.compactMap { frame.intersection($0.frame) }.reduce(0) { $0 + $1.w * $1.h }
    return visible < 0.1 * frame.w * frame.h
}

public func recoveryFrame(for frame: Rect, on main: MonitorInfo) -> Rect {
    let u = main.usable
    let w = min(frame.w, u.w)
    let h = min(frame.h, u.h)
    return Rect(x: u.x + (u.w - w) / 2, y: u.y + (u.h - h) / 2, w: w, h: h)
}
