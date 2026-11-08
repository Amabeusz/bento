public typealias MonitorID = UInt32

public struct MonitorInfo: Equatable, Sendable {
    public var id: MonitorID
    public var frame: Rect
    public var usable: Rect
    public var isBuiltin: Bool

    public init(id: MonitorID, frame: Rect, usable: Rect, isBuiltin: Bool) {
        self.id = id
        self.frame = frame
        self.usable = usable
        self.isBuiltin = isBuiltin
    }
}

public struct WindowInfo: Equatable, Sendable {
    public var id: WindowID
    public var app: String
    public var title: String
    public var isDialog: Bool
    public var frame: Rect

    public init(id: WindowID, app: String, title: String, isDialog: Bool, frame: Rect) {
        self.id = id
        self.app = app
        self.title = title
        self.isDialog = isDialog
        self.frame = frame
    }
}

public struct WindowMemory: Codable, Equatable, Sendable {
    public var id: WindowID
    public var app: String
    public var workspace: Int

    public init(id: WindowID, app: String, workspace: Int) {
        self.id = id
        self.app = app
        self.workspace = workspace
    }
}

public enum Placement: Equatable, Sendable {
    case tiled(Rect)
    case floating(Rect)
    case parked(Rect)
}

public struct WorkspaceBadge: Equatable, Sendable {
    public var number: Int
    public var isHere: Bool
    public var isOnOtherMonitor: Bool
    public var isEmpty: Bool
    public var icons: [WindowID]

    public init(number: Int, isHere: Bool, isOnOtherMonitor: Bool, isEmpty: Bool, icons: [WindowID] = []) {
        self.number = number
        self.isHere = isHere
        self.isOnOtherMonitor = isOnOtherMonitor
        self.isEmpty = isEmpty
        self.icons = icons
    }
}

public struct LayoutSnapshot: Equatable, Sendable {
    public var placements: [WindowID: Placement]
    public var focused: WindowID?
    public var bars: [MonitorID: [WorkspaceBadge]]
    public var visibleWorkspace: [MonitorID: Int]

    public init(
        placements: [WindowID: Placement], focused: WindowID?,
        bars: [MonitorID: [WorkspaceBadge]], visibleWorkspace: [MonitorID: Int]
    ) {
        self.placements = placements
        self.focused = focused
        self.bars = bars
        self.visibleWorkspace = visibleWorkspace
    }
}

public enum SideEffect: Equatable, Sendable {
    case exec(String)
    case launchApp(String)
    case closeWindow(WindowID)
    case focusWindow(WindowID)
    case focusNothing
    case warpCursor(Point)
    case toggleOverview
}

public final class World {
    private var config: Config
    private var monitors: [MonitorInfo] = []
    private var known: [MonitorID: MonitorInfo] = [:]
    private var visible: [MonitorID: Int] = [:]
    private var lastMonitor: [Int: MonitorID] = [:]
    private var shownBeforeUnplug: [MonitorID: Int] = [:]
    private var windows: [WindowID: WindowInfo] = [:]
    private var workspaceOf: [WindowID: Int] = [:]
    private var trees: [Int: DwindleTree] = [:]
    private var floating: [WindowID: Rect] = [:]
    private var fullscreen: Set<WindowID> = []
    private var history: [WindowID] = []
    private var focused: WindowID?
    private var focusedMonitor: MonitorID?
    private var remembered: [WindowID: WindowMemory] = [:]

    public init(config: Config) {
        self.config = config
    }

    public func updateConfig(_ c: Config) {
        config = c
    }

    public func setMonitors(_ ms: [MonitorInfo]) {
        let focusedBefore = currentMonitor?.id
        for m in ms { known[m.id] = m }
        let ordered = ms.filter(\.isBuiltin) + ms.filter { !$0.isBuiltin }
        let kept = Set(ordered.map(\.id))
        for m in monitors where !kept.contains(m.id) {
            shownBeforeUnplug[m.id] = visible.removeValue(forKey: m.id)
        }
        let builtinBefore = monitors.first(where: \.isBuiltin).flatMap { visible[$0.id] }
        let wasPinned = pinnedMonitors
        monitors = ordered
        if let was = wasPinned, pinnedMonitors == nil {
            releasePinned(from: was)
        }
        if let builtin = pinnedMonitors?.builtin, visible[builtin.id] != pinnedBuiltin {
            visible[builtin.id] = nil
            if let holder = monitorShowing(pinnedBuiltin) { visible[holder.id] = nil }
            show(pinnedBuiltin, on: builtin.id)
        }
        if let external = pinnedMonitors?.external, visible[external.id] == nil,
           let n = builtinBefore, n != pinnedBuiltin, isHidden(n) {
            show(n, on: external.id)
        }
        for m in ordered where visible[m.id] == nil {
            let preferred = shownBeforeUnplug[m.id] ?? config.startupWorkspace[m.isBuiltin ? .builtin : .external]
            guard let n = preferred.flatMap({ available.contains($0) && isHidden($0) ? $0 : nil }) ?? lowestHidden() else { continue }
            show(n, on: m.id)
        }
        if let before = focusedBefore, !kept.contains(before), let first = ordered.first {
            focusedMonitor = first.id
            focus(visible[first.id].flatMap(lastFocused(in:)))
        }
        if let id = focused, let n = workspaceOf[id], isHidden(n), let m = currentMonitor {
            focus(visible[m.id].flatMap(lastFocused(in:)))
        }
    }

    public func remember(_ entries: [WindowMemory]) {
        remembered = Dictionary(entries.map { ($0.id, $0) }) { _, last in last }
    }

    public var memory: [WindowMemory] {
        let live = workspaceOf.compactMap { id, n in windows[id].map { WindowMemory(id: id, app: $0.app, workspace: n) } }
        return (live + remembered.values.filter { windows[$0.id] == nil }).sorted { $0.id < $1.id }
    }

    public func addWindow(_ w: WindowInfo) {
        guard windows[w.id] == nil else { return }
        let monitor = focusedMonitor == nil
            ? monitors.first { $0.frame.contains(w.frame.center) } ?? monitors.first
            : currentMonitor
        let saved = remembered.removeValue(forKey: w.id)
            .flatMap { $0.app == w.app && available.contains($0.workspace) ? $0.workspace : nil }
        let n = saved ?? monitor.flatMap { visible[$0.id] } ?? 1
        windows[w.id] = w
        workspaceOf[w.id] = n
        if shouldFloat(w) {
            floating[w.id] = w.frame
            if w.isDialog { placeOverItsApp(w) }
        } else {
            insertTiled(w.id, into: n)
        }
        if saved != nil, isHidden(n) {
            history.append(w.id)
        } else {
            focus(w.id)
        }
    }

    public func removeWindow(_ id: WindowID) {
        guard let n = workspaceOf[id] else { return }
        detach(id)
        windows[id] = nil
        workspaceOf[id] = nil
        floating[id] = nil
        history.removeAll { $0 == id }
        if focused == id { focused = lastFocused(in: n) }
    }

    public func replaceWindow(_ old: WindowID, with new: WindowInfo) {
        guard let n = workspaceOf[old], windows[new.id] == nil else { return }
        windows[new.id] = new
        workspaceOf[new.id] = n
        trees[n]?.replace(old, with: new.id)
        floating[new.id] = floating.removeValue(forKey: old)
        if fullscreen.remove(old) != nil { fullscreen.insert(new.id) }
        history = history.map { $0 == old ? new.id : $0 }
        if focused == old { focused = new.id }
        windows[old] = nil
        workspaceOf[old] = nil
    }

    public func externalFocus(_ id: WindowID) {
        guard let n = workspaceOf[id] else { return }
        if let m = monitorShowing(n) {
            focusedMonitor = m.id
            focus(id)
        } else {
            _ = goTo(n, focusing: id)
        }
    }

    public func perform(_ a: Action) -> [SideEffect] {
        focusedMonitor = currentMonitor?.id
        switch a {
        case .exec(let command):
            return [.exec(command)]
        case .killActive:
            return focused.map { [.closeWindow($0)] } ?? []
        case .workspace(let n):
            return goTo(n, focusing: nil)
        case .focusOrLaunch(let app):
            guard let id = history.first(where: { windows[$0]?.app == app }), let n = workspaceOf[id] else {
                return [.launchApp(app)]
            }
            return goTo(n, focusing: id)
        case .moveToWorkspace(let n):
            return moveToWorkspace(n)
        case .moveCurrentWorkspaceToMonitor:
            return moveCurrentWorkspaceToMonitor()
        case .moveFocus(let dir):
            return moveFocus(dir)
        case .moveWindow(let dir):
            return moveWindow(dir)
        case .resizeActive(let dx, let dy):
            guard let id = focused, let n = workspaceOf[id] else { return [] }
            if let f = floating[id] {
                floating[id] = clamped(Rect(x: f.x, y: f.y, w: f.w + dx, h: f.h + dy), from: f)
            } else {
                trees[n]?.resize(id, dx: dx, dy: dy, area: area(of: n), gapsIn: config.gapsIn)
            }
            return []
        case .toggleSplit:
            guard let id = focused, let n = workspaceOf[id] else { return [] }
            trees[n]?.toggleSplit(of: id)
            return []
        case .fullscreen:
            guard let id = focused else { return [] }
            if fullscreen.remove(id) == nil { fullscreen.insert(id) }
            return []
        case .toggleFloating:
            guard let id = focused, let n = workspaceOf[id], let w = windows[id] else { return [] }
            if floating.removeValue(forKey: id) != nil {
                insertTiled(id, into: n)
            } else {
                floating[id] = trees[n]?.frames(in: area(of: n), gapsIn: config.gapsIn)[id] ?? w.frame
                trees[n]?.remove(id)
            }
            return []
        case .overview:
            return [.toggleOverview]
        }
    }

    public func setFloatingFrame(_ id: WindowID, _ r: Rect) {
        guard let f = floating[id] else { return }
        floating[id] = clamped(r, from: f)
    }

    private func clamped(_ r: Rect, from old: Rect) -> Rect {
        Rect(x: r.x, y: r.y, w: max(r.w, min(100, old.w)), h: max(r.h, min(60, old.h)))
    }

    public func dropTiled(_ id: WindowID, at p: Point) {
        guard let n = workspaceOf[id],
              let frames = trees[n]?.frames(in: area(of: n), gapsIn: config.gapsIn), frames[id] != nil,
              let target = frames.first(where: { $0.key != id && $0.value.contains(p) })?.key
        else { return }
        trees[n]?.swap(id, target)
    }

    public func resizeTiled(_ id: WindowID, dx: Double, dy: Double) {
        guard let n = workspaceOf[id] else { return }
        trees[n]?.resize(id, dx: dx, dy: dy, area: area(of: n), gapsIn: config.gapsIn)
    }

    public func snapshot() -> LayoutSnapshot {
        var placements: [WindowID: Placement] = [:]
        for n in World.allWorkspaces {
            guard let home = homeMonitor(of: n) else { continue }
            let shown = monitorShowing(n) != nil
            for (id, frame) in layoutFrames(of: n, on: home) {
                let isFullscreen = fullscreen.contains(id)
                placements[id] =
                    if !shown { .parked(parkFrame(for: frame, on: home, monitors: monitors)) }
                    else if floating[id] != nil && !isFullscreen { .floating(frame) }
                    else { .tiled(frame) }
            }
        }
        var bars: [MonitorID: [WorkspaceBadge]] = [:]
        for m in monitors {
            bars[m.id] = workspaces(shownOn: m).map { n in
                WorkspaceBadge(
                    number: n,
                    isHere: visible[m.id] == n,
                    isOnOtherMonitor: visible.contains { $0.key != m.id && $0.value == n },
                    isEmpty: isEmpty(n),
                    icons: config.barIcons ? icons(of: n) : []
                )
            }
        }
        return LayoutSnapshot(placements: placements, focused: focused, bars: bars, visibleWorkspace: visible)
    }

    public func overview(on monitor: MonitorID) -> [OverviewItem] {
        World.allWorkspaces.flatMap { n -> [OverviewItem] in
            guard let home = pinnedTarget(for: n) ?? homeMonitor(of: n), home.id == monitor else { return [] }
            let frames = layoutFrames(of: n, on: home)
            let floats = frames.keys.filter { floating[$0] != nil }.sorted()
            return ((trees[n]?.windows ?? []) + floats).compactMap { id in
                frames[id].map { OverviewItem(id: id, workspace: n, frame: $0) }
            }
        }
    }

    private func layoutFrames(of n: Int, on home: MonitorInfo) -> [WindowID: Rect] {
        let area = tilingArea(home)
        let tiles = trees[n]?.frames(in: area, gapsIn: config.gapsIn) ?? [:]
        var frames: [WindowID: Rect] = [:]
        for (id, ws) in workspaceOf where ws == n {
            frames[id] = fullscreen.contains(id) ? area : floating[id] ?? tiles[id] ?? area
        }
        return frames
    }

    private func goTo(_ n: Int, focusing window: WindowID?) -> [SideEffect] {
        guard available.contains(n), let current = currentMonitor else { return [] }
        let target: MonitorInfo
        if let m = monitorShowing(n) {
            target = m
        } else {
            target = pinnedTarget(for: n) ?? current
            show(n, on: target.id)
        }
        focusedMonitor = target.id
        focus(window ?? lastFocused(in: n))
        return focusEffects(warpTo: target.id != current.id ? target : nil)
    }

    private func moveToWorkspace(_ n: Int) -> [SideEffect] {
        guard available.contains(n), let id = focused, let source = workspaceOf[id], source != n else { return [] }
        move(id, to: n)
        focus(lastFocused(in: source))
        return focusEffects(warpTo: nil)
    }

    private func moveCurrentWorkspaceToMonitor() -> [SideEffect] {
        guard pinnedMonitors == nil, monitors.count == 2, let current = currentMonitor, let mine = visible[current.id],
              let other = monitors.first(where: { $0.id != current.id }), let theirs = visible[other.id]
        else { return [] }
        if isEmpty(theirs) {
            visible[current.id] = nil
            show(mine, on: other.id)
            if let n = lowestHidden() { show(n, on: current.id) }
        } else {
            show(theirs, on: current.id)
            show(mine, on: other.id)
        }
        focusedMonitor = other.id
        return focusEffects(warpTo: other)
    }

    private func moveFocus(_ dir: Direction) -> [SideEffect] {
        guard let current = currentMonitor, let n = visible[current.id] else { return [] }
        if let id = focused, let next = trees[n]?.neighbor(of: id, dir, area: area(of: n), gapsIn: config.gapsIn) {
            focus(next)
            return [.focusWindow(next)]
        }
        if dir == .up || dir == .down {
            return cycleMonitor(from: current, by: dir == .down ? 1 : -1)
        }
        return adjacentWorkspace(dir, on: current).map { goTo($0, focusing: nil) } ?? []
    }

    private func cycleMonitor(from current: MonitorInfo, by step: Int) -> [SideEffect] {
        guard let m = monitor(after: current, by: step) else { return [] }
        focusedMonitor = m.id
        focus(visible[m.id].flatMap(lastFocused(in:)))
        return focusEffects(warpTo: m)
    }

    private func monitor(after current: MonitorInfo, by step: Int) -> MonitorInfo? {
        let order = monitors.sorted { ($0.frame.x, $0.frame.y) < ($1.frame.x, $1.frame.y) }
        guard order.count > 1, let i = order.firstIndex(of: current) else { return nil }
        return order[(i + step + order.count) % order.count]
    }

    private func adjacentWorkspace(_ dir: Direction, on m: MonitorInfo) -> Int? {
        guard let n = visible[m.id], dir == .left || dir == .right else { return nil }
        let others = workspaces(shownOn: m).filter { isHidden($0) && !isEmpty($0) }
        return dir == .right ? others.filter { $0 > n }.min() : others.filter { $0 < n }.max()
    }

    private func moveWindow(_ dir: Direction) -> [SideEffect] {
        guard let id = focused, let n = workspaceOf[id], let current = currentMonitor else { return [] }
        if let next = trees[n]?.neighbor(of: id, dir, area: area(of: n), gapsIn: config.gapsIn) {
            trees[n]?.swap(id, next)
            return []
        }
        if dir == .up || dir == .down {
            guard let m = monitor(after: current, by: dir == .down ? 1 : -1), let target = visible[m.id] else { return [] }
            move(id, to: target)
            focusedMonitor = m.id
            return focusEffects(warpTo: m)
        }
        let target = dir == .right ? n + 1 : n - 1
        guard workspaces(shownOn: current).contains(target), isHidden(target) else { return [] }
        move(id, to: target)
        return goTo(target, focusing: id)
    }

    private func move(_ id: WindowID, to n: Int) {
        let source = workspaceOf[id].flatMap(frameMonitor(of:))
        detach(id)
        workspaceOf[id] = n
        if let f = floating[id] {
            if let target = frameMonitor(of: n), target.id != source?.id {
                floating[id] = relocate(f, from: source, to: target)
            }
        } else {
            insertTiled(id, into: n)
        }
    }

    private func frameMonitor(of n: Int) -> MonitorInfo? {
        lastMonitor[n].flatMap { known[$0] }
    }

    private func relocate(_ r: Rect, from source: MonitorInfo?, to target: MonitorInfo) -> Rect {
        let u = target.usable
        let w = min(r.w, u.w)
        let h = min(r.h, u.h)
        let x = r.x + (source.map { u.x - $0.usable.x } ?? 0)
        let y = r.y + (source.map { u.y - $0.usable.y } ?? 0)
        return Rect(x: min(max(x, u.minX), u.maxX - w), y: min(max(y, u.minY), u.maxY - h), w: w, h: h)
    }

    private func detach(_ id: WindowID) {
        if let n = workspaceOf[id] { trees[n]?.remove(id) }
        fullscreen.remove(id)
    }

    private func insertTiled(_ id: WindowID, into n: Int) {
        let target = history.first { trees[n]?.contains($0) == true }
        let area = area(of: n)
        trees[n, default: DwindleTree()].insert(id, splitting: target, area: area, gapsIn: config.gapsIn)
    }

    private func focus(_ id: WindowID?) {
        focused = id
        guard let id else { return }
        history.removeAll { $0 == id }
        history.insert(id, at: 0)
    }

    private func focusEffects(warpTo m: MonitorInfo?) -> [SideEffect] {
        var effects: [SideEffect] = [focused.map { .focusWindow($0) } ?? .focusNothing]
        if let m, config.warpCursor { effects.append(.warpCursor(m.frame.center)) }
        return effects
    }

    private func placeOverItsApp(_ w: WindowInfo) {
        guard let parent = history.first(where: { $0 != w.id && windows[$0]?.app == w.app && floating[$0] == nil }),
              let n = workspaceOf[parent], let home = homeMonitor(of: n),
              let p = trees[n]?.frames(in: area(of: n), gapsIn: config.gapsIn)[parent]
        else { return }
        workspaceOf[w.id] = n
        let centered = Rect(x: p.center.x - w.frame.w / 2, y: p.center.y - w.frame.h / 2, w: w.frame.w, h: w.frame.h)
        floating[w.id] = relocate(centered, from: nil, to: home)
    }

    private func shouldFloat(_ w: WindowInfo) -> Bool {
        w.isDialog || config.floatRules.contains { matches($0.appPattern, w.app) && matches($0.titlePattern, w.title) }
    }

    private func matches(_ pattern: String?, _ text: String) -> Bool {
        guard let pattern else { return true }
        guard let regex = try? Regex(pattern) else { return false }
        return text.contains(regex)
    }

    private func lastFocused(in n: Int) -> WindowID? {
        history.first { workspaceOf[$0] == n }
    }

    private var currentMonitor: MonitorInfo? {
        focusedMonitor.flatMap(monitor(_:))
            ?? focused.flatMap { workspaceOf[$0] }.flatMap(monitorShowing(_:))
            ?? monitors.first
    }

    private func monitor(_ id: MonitorID) -> MonitorInfo? {
        monitors.first { $0.id == id }
    }

    private func monitorShowing(_ n: Int) -> MonitorInfo? {
        monitors.first { visible[$0.id] == n }
    }

    private func homeMonitor(of n: Int) -> MonitorInfo? {
        monitorShowing(n) ?? lastMonitor[n].flatMap(monitor(_:)) ?? monitors.first
    }

    private func tilingArea(_ m: MonitorInfo) -> Rect {
        var a = m.usable
        if config.barEnabled {
            let reserve = config.barHeight + config.barMarginTop + config.barMarginBottom
            a.y += reserve
            a.h -= reserve
        }
        return a.inset(by: config.gapsOut)
    }

    private func area(of n: Int) -> Rect {
        homeMonitor(of: n).map(tilingArea) ?? Rect(x: 0, y: 0, w: 0, h: 0)
    }

    private func show(_ n: Int, on id: MonitorID) {
        if lastMonitor[n] != id, let target = known[id] {
            let source = frameMonitor(of: n)
            for (w, ws) in workspaceOf where ws == n {
                if let f = floating[w] { floating[w] = relocate(f, from: source, to: target) }
            }
        }
        visible[id] = n
        lastMonitor[n] = id
    }

    private static let allWorkspaces = 0...9
    private let pinnedBuiltin = 0

    private var available: [Int] {
        pinnedMonitors == nil ? Array(1...9) : Array(World.allWorkspaces)
    }

    private func releasePinned(from was: (builtin: MonitorInfo, external: MonitorInfo)) {
        let stranded = workspaceOf.filter { $0.value == pinnedBuiltin }.map(\.key).sorted()
        if !stranded.isEmpty, let target = (1...9).first(where: isEmpty) ?? lowestHidden() {
            stranded.forEach { move($0, to: target) }
        }
        for (id, n) in visible where n == pinnedBuiltin {
            visible[id] = nil
            if let n = shownBeforeUnplug[was.external.id], isHidden(n) { show(n, on: id) }
        }
    }

    private var pinnedMonitors: (builtin: MonitorInfo, external: MonitorInfo)? {
        guard monitors.count > 1, let builtin = monitors.first(where: \.isBuiltin),
              let external = monitors.first(where: { !$0.isBuiltin }) else { return nil }
        return (builtin, external)
    }

    private func pinnedTarget(for n: Int) -> MonitorInfo? {
        pinnedMonitors.map { n == pinnedBuiltin ? $0.builtin : $0.external }
    }

    private func workspaces(shownOn m: MonitorInfo) -> [Int] {
        guard pinnedMonitors != nil else { return Array(1...9) }
        return m.isBuiltin ? [pinnedBuiltin] : Array(1...9)
    }

    private func isHidden(_ n: Int) -> Bool {
        !visible.values.contains(n)
    }

    private func isEmpty(_ n: Int) -> Bool {
        !workspaceOf.values.contains(n)
    }

    private func icons(of n: Int) -> [WindowID] {
        let tiled = trees[n]?.windows ?? []
        let floats = workspaceOf.filter { $0.value == n && floating[$0.key] != nil }.keys.sorted()
        var apps: Set<String> = []
        return (tiled + floats).filter { windows[$0].map { apps.insert($0.app).inserted } ?? false }
    }

    private func lowestHidden() -> Int? {
        available.first(where: isHidden)
    }
}
