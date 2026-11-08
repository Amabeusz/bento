import AppKit
import BentoCore
import QuartzCore
@preconcurrency import ScreenCaptureKit

enum TransitionKind {
    case layout
    case workspace(monitor: MonitorID, forward: Bool)

    init(from old: LayoutSnapshot, to new: LayoutSnapshot) {
        for (monitor, number) in new.visibleWorkspace.sorted(by: { $0.key < $1.key }) {
            if let previous = old.visibleWorkspace[monitor], previous != number {
                self = .workspace(monitor: monitor, forward: number > previous)
                return
            }
        }
        self = .layout
    }
}

@MainActor
final class Animator {
    var config = Config()
    var onActiveChange: (Bool) -> Void = { _ in }

    private var running: Running?
    private var content: SCShareableContent?
    private var refreshing = false
    private var refreshAgain = false
    private var cache: [WindowID: CGImage] = [:]

    @MainActor
    private final class Running {
        var apply: (() -> Void)?
        var overlays: [NSWindow] = []

        init(apply: @escaping () -> Void) {
            self.apply = apply
        }

        func runApply() {
            let apply = self.apply
            self.apply = nil
            apply?()
        }
    }

    private struct Item {
        let id: WindowID
        let monitor: MonitorInfo
        let from: Rect
        let to: Rect
        var opacity: (from: Float, to: Float) = (1, 1)
        var scale = 1.0
        var image: CGImage?
    }

    private struct Plan {
        var items: [Item] = []
        var monitors: [MonitorID: MonitorInfo] = [:]
        var captures: [WindowID: CGSize] = [:]
        var parking: Set<WindowID> = []
        var excluded: Set<WindowID> = []
        let duration: Double
        let curve: CubicBezierSpec

        mutating func add(_ item: Item) {
            items.append(item)
            monitors[item.monitor.id] = item.monitor
        }
    }

    private enum Target {
        case window(WindowID)
        case display(MonitorID)
    }

    func transition(from old: LayoutSnapshot, to new: LayoutSnapshot, kind: TransitionKind, apply: @escaping () -> Void) {
        let wasActive = running != nil
        if let running { complete(running, notify: false) }
        if content == nil { refreshContent() }
        let plan = makePlan(from: old, to: new, kind: kind)
        cache = cache.filter { if case .parked = new.placements[$0.key] { true } else { false } }
        guard let plan, !plan.monitors.isEmpty else {
            apply()
            if wasActive { onActiveChange(false) }
            return
        }
        let transition = Running(apply: apply)
        running = transition
        if !wasActive { onActiveChange(true) }
        Task {
            let (images, backdrops) = await capture(plan)
            for id in plan.parking {
                if let image = images[id] { cache[id] = image }
            }
            guard running === transition, transition.apply != nil else { return }
            guard plan.monitors.keys.allSatisfy({ backdrops[$0] != nil }) else { return complete(transition, notify: true) }
            show(plan, images: images, backdrops: backdrops, for: transition)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            if running === transition, transition.apply != nil { complete(transition, notify: true) }
        }
    }

    func finish() {
        if let running { complete(running, notify: true) }
    }

    func refreshContent() {
        guard CGPreflightScreenCaptureAccess() else { return }
        if refreshing {
            refreshAgain = true
            return
        }
        refreshing = true
        Task {
            if let fresh = try? await SCShareableContent.current { content = fresh }
            refreshing = false
            if refreshAgain {
                refreshAgain = false
                refreshContent()
            }
        }
    }

    private func complete(_ transition: Running, notify: Bool) {
        transition.runApply()
        transition.overlays.forEach { $0.orderOut(nil); $0.close() }
        transition.overlays = []
        guard running === transition else { return }
        running = nil
        refreshContent()
        if notify { onActiveChange(false) }
    }

    private func makePlan(from old: LayoutSnapshot, to new: LayoutSnapshot, kind: TransitionKind) -> Plan? {
        let name = if case .layout = kind { "windows" } else { "workspaces" }
        guard config.animationsEnabled, let spec = config.animations[name], spec.enabled,
              let curve = config.beziers[spec.curve] ?? config.beziers["default"],
              content != nil, CGPreflightScreenCaptureAccess()
        else { return nil }
        let monitors = monitorInfos()
        let scales = backingScales()
        func monitor(of r: Rect) -> MonitorInfo? { monitors.first { $0.frame.contains(r.center) } }
        func pixels(_ r: Rect, on m: MonitorInfo) -> CGSize {
            let s = scales[m.id] ?? 2
            return CGSize(width: r.w * s, height: r.h * s)
        }
        var plan = Plan(duration: spec.duration, curve: curve)
        plan.excluded = Set(old.placements.keys).union(new.placements.keys).filter { old.placements[$0] != new.placements[$0] }
        for (id, placement) in old.placements {
            guard let from = visibleFrame(placement), case .parked? = new.placements[id], let m = monitor(of: from) else { continue }
            plan.parking.insert(id)
            plan.captures[id] = pixels(from, on: m)
        }
        func move(_ id: WindowID, from: Rect, to: Rect, on m: MonitorInfo) {
            guard from != to, let origin = monitor(of: from) else { return }
            plan.add(Item(id: id, monitor: m, from: from, to: to))
            plan.captures[id] = pixels(from, on: origin)
        }
        switch kind {
        case .layout:
            for (id, placement) in new.placements {
                guard let to = visibleFrame(placement), let m = monitor(of: to) else { continue }
                if let previous = old.placements[id] {
                    if let from = visibleFrame(previous) { move(id, from: from, to: to, on: m) }
                } else {
                    plan.add(Item(id: id, monitor: m, from: to, to: to, opacity: (0, 1), scale: 0.9))
                    plan.captures[id] = pixels(to, on: m)
                }
            }
        case .workspace(let monitorID, let forward):
            guard let m = monitors.first(where: { $0.id == monitorID }) else { return nil }
            let slide = spec.style != "fade"
            let shift = (forward ? -1.0 : 1.0) * m.frame.w
            func shifted(_ r: Rect, _ dx: Double) -> Rect { Rect(x: r.x + dx, y: r.y, w: r.w, h: r.h) }
            for (id, placement) in old.placements {
                guard let from = visibleFrame(placement), m.frame.contains(from.center), plan.parking.contains(id) else { continue }
                plan.add(slide
                    ? Item(id: id, monitor: m, from: from, to: shifted(from, shift))
                    : Item(id: id, monitor: m, from: from, to: from, opacity: (1, 0)))
            }
            for (id, placement) in new.placements {
                guard let to = visibleFrame(placement), m.frame.contains(to.center) else { continue }
                if let from = old.placements[id].flatMap(visibleFrame) {
                    move(id, from: from, to: to, on: m)
                } else if let image = cache[id] {
                    plan.add(slide
                        ? Item(id: id, monitor: m, from: shifted(to, -shift), to: to, image: image)
                        : Item(id: id, monitor: m, from: to, to: to, opacity: (0, 1), image: image))
                } else {
                    plan.monitors[m.id] = m
                }
            }
        }
        return plan
    }

    private func visibleFrame(_ placement: Placement) -> Rect? {
        switch placement {
        case .tiled(let r), .floating(let r): r
        case .parked: nil
        }
    }

    private func backingScales() -> [MonitorID: CGFloat] {
        var scales: [MonitorID: CGFloat] = [:]
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                scales[number.uint32Value] = screen.backingScaleFactor
            }
        }
        return scales
    }

    private func capture(_ plan: Plan) async -> (windows: [WindowID: CGImage], displays: [MonitorID: CGImage]) {
        let windows = content?.windows ?? []
        let displays = content?.displays ?? []
        let scales = backingScales()
        let pid = getpid()
        let backdropWindows = windows.filter { !plan.excluded.contains($0.windowID) && $0.owningApplication?.processID != pid }
        var requests: [(Target, SCContentFilter, CGSize)] = []
        for window in windows {
            if let size = plan.captures[window.windowID] {
                requests.append((.window(window.windowID), SCContentFilter(desktopIndependentWindow: window), size))
            }
        }
        for display in displays {
            guard let m = plan.monitors[display.displayID] else { continue }
            let s = scales[m.id] ?? 2
            requests.append((.display(m.id), SCContentFilter(display: display, including: backdropWindows),
                             CGSize(width: m.frame.w * s, height: m.frame.h * s)))
        }
        return await withTaskGroup(of: (Target, CGImage?).self) { group in
            for (target, filter, size) in requests {
                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int(size.width.rounded()))
                configuration.height = max(1, Int(size.height.rounded()))
                configuration.scalesToFit = true
                configuration.preservesAspectRatio = false
                configuration.showsCursor = false
                configuration.ignoreShadowsSingleWindow = true
                group.addTask {
                    (target, try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration))
                }
            }
            var images: [WindowID: CGImage] = [:]
            var backdrops: [MonitorID: CGImage] = [:]
            for await case (let target, let image?) in group {
                switch target {
                case .window(let id): images[id] = image
                case .display(let id): backdrops[id] = image
                }
            }
            return (images, backdrops)
        }
    }

    private func show(_ plan: Plan, images: [WindowID: CGImage], backdrops: [MonitorID: CGImage], for transition: Running) {
        let scales = backingScales()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for monitor in plan.monitors.values {
            guard let frame = appKitFrame(monitor.frame), let backdrop = backdrops[monitor.id] else { continue }
            let scale = scales[monitor.id] ?? 2
            let window = makeOverlay(frame: frame)
            let root = CALayer()
            root.frame = CGRect(origin: .zero, size: frame.size)
            let background = CALayer()
            background.frame = root.bounds
            background.contents = backdrop
            background.contentsScale = scale
            root.addSublayer(background)
            for item in plan.items where item.monitor.id == monitor.id {
                guard let image = item.image ?? images[item.id] else { continue }
                root.addSublayer(layer(for: item, image: image, in: monitor.frame, scale: scale, plan: plan))
            }
            root.add(fadeOut(plan), forKey: "fadeOut")
            window.contentView?.layer?.addSublayer(root)
            window.orderFrontRegardless()
            transition.overlays.append(window)
        }
        CATransaction.commit()
        CATransaction.flush()
        transition.runApply()
        Task {
            try? await Task.sleep(for: .seconds(plan.duration))
            complete(transition, notify: true)
        }
    }

    private func makeOverlay(frame: NSRect) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        window.contentView = view
        return window
    }

    private func fadeOut(_ plan: Plan) -> CABasicAnimation {
        let length = min(0.1, plan.duration)
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.beginTime = CACurrentMediaTime() + plan.duration - length
        animation.duration = length
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }

    private func layer(for item: Item, image: CGImage, in monitor: Rect, scale: CGFloat, plan: Plan) -> CALayer {
        func local(_ r: Rect) -> CGRect {
            CGRect(x: r.x - monitor.x, y: monitor.maxY - r.maxY, width: r.w, height: r.h)
        }
        func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }
        let start = local(item.from)
        let end = local(item.to)
        let layer = CALayer()
        layer.contents = image
        layer.contentsScale = scale
        layer.frame = end
        layer.opacity = item.opacity.to
        var animations: [CAKeyframeAnimation] = []
        if start != end {
            animations.append(keyframes("position", plan) { p in
                NSValue(point: CGPoint(x: lerp(start.midX, end.midX, p), y: lerp(start.midY, end.midY, p)))
            })
            animations.append(keyframes("bounds", plan) { p in
                NSValue(rect: CGRect(x: 0, y: 0, width: lerp(start.width, end.width, p), height: lerp(start.height, end.height, p)))
            })
        }
        if item.opacity.from != item.opacity.to {
            let (from, to) = (Double(item.opacity.from), Double(item.opacity.to))
            animations.append(keyframes("opacity", plan) { p in NSNumber(value: min(1, max(0, lerp(from, to, p)))) })
        }
        if item.scale != 1 {
            animations.append(keyframes("transform.scale", plan) { p in NSNumber(value: lerp(item.scale, 1, p)) })
        }
        for animation in animations {
            layer.add(animation, forKey: animation.keyPath)
        }
        return layer
    }

    private func keyframes(_ keyPath: String, _ plan: Plan, value: (Double) -> Any) -> CAKeyframeAnimation {
        let samples = 60
        let times = (0..<samples).map { Double($0) / Double(samples - 1) }
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.keyTimes = times.map { NSNumber(value: $0) }
        animation.values = times.map { value(plan.curve.progress(at: $0)) }
        animation.calculationMode = .linear
        animation.duration = plan.duration
        return animation
    }
}
