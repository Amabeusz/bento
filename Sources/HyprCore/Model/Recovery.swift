public func parkFrame(for size: Rect, on monitor: MonitorInfo) -> Rect {
    Rect(x: monitor.frame.maxX - 1, y: monitor.frame.maxY - 1, w: size.w, h: size.h)
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
