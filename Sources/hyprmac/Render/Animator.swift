import AppKit
import HyprCore
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
        var captures: [WindowID: CGSize] = [:]
        var parking: Set<WindowID> = []
        let duration: Double
        let curve: CubicBezierSpec
    }

    func transition(from old: LayoutSnapshot, to new: LayoutSnapshot, kind: TransitionKind, apply: @escaping () -> Void) {
        let wasActive = running != nil
        if let running { complete(running, notify: false) }
        let plan = makePlan(from: old, to: new, kind: kind)
        cache = cache.filter { if case .parked = new.placements[$0.key] { true } else { false } }
        guard let plan, !plan.items.isEmpty else {
            apply()
            if wasActive { onActiveChange(false) }
            return
        }
        let transition = Running(apply: apply)
        running = transition
        if !wasActive { onActiveChange(true) }
        Task {
            let images = await capture(plan.captures)
            for id in plan.parking {
                if let image = images?[id] { cache[id] = image }
            }
            guard running === transition, transition.apply != nil else { return }
            guard let images else { return complete(transition, notify: true) }
            show(plan, images: images, for: transition)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            if running === transition, transition.apply != nil { complete(transition, notify: true) }
        }
    }

    func finish() {
        if let running { complete(running, notify: true) }
    }

    private func complete(_ transition: Running, notify: Bool) {
        transition.runApply()
        transition.overlays.forEach { $0.orderOut(nil); $0.close() }
        transition.overlays = []
        guard running === transition else { return }
        running = nil
        if notify { onActiveChange(false) }
    }

    private func makePlan(from old: LayoutSnapshot, to new: LayoutSnapshot, kind: TransitionKind) -> Plan? {
        let name = if case .layout = kind { "windows" } else { "workspaces" }
        guard config.animationsEnabled, let spec = config.animations[name], spec.enabled,
              let curve = config.beziers[spec.curve] ?? config.beziers["default"],
              CGPreflightScreenCaptureAccess()
        else { return nil }
        let monitors = monitorInfos()
        let scales = backingScales()
        func monitor(of r: Rect) -> MonitorInfo? { monitors.first { $0.frame.contains(r.center) } }
        func pixels(_ r: Rect, on m: MonitorInfo) -> CGSize {
            let s = scales[m.id] ?? 2
            return CGSize(width: r.w * s, height: r.h * s)
        }
        var plan = Plan(duration: spec.duration, curve: curve)
        for (id, placement) in old.placements {
            guard let from = visibleFrame(placement), case .parked? = new.placements[id], let m = monitor(of: from) else { continue }
            plan.parking.insert(id)
            plan.captures[id] = pixels(from, on: m)
        }
        func move(_ id: WindowID, from: Rect, to: Rect, on m: MonitorInfo) {
            guard from != to, let origin = monitor(of: from) else { return }
            plan.items.append(Item(id: id, monitor: m, from: from, to: to))
            plan.captures[id] = pixels(from, on: origin)
        }
        switch kind {
        case .layout:
            for (id, placement) in new.placements {
                guard let to = visibleFrame(placement), let m = monitor(of: to) else { continue }
                if let previous = old.placements[id] {
                    if let from = visibleFrame(previous) { move(id, from: from, to: to, on: m) }
                } else {
                    plan.items.append(Item(id: id, monitor: m, from: to, to: to, opacity: (0, 1), scale: 0.9))
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
                plan.items.append(slide
                    ? Item(id: id, monitor: m, from: from, to: shifted(from, shift))
                    : Item(id: id, monitor: m, from: from, to: from, opacity: (1, 0)))
            }
            for (id, placement) in new.placements {
                guard let to = visibleFrame(placement), m.frame.contains(to.center) else { continue }
                if let from = old.placements[id].flatMap(visibleFrame) {
                    move(id, from: from, to: to, on: m)
                } else if let image = cache[id] {
                    plan.items.append(slide
                        ? Item(id: id, monitor: m, from: shifted(to, -shift), to: to, image: image)
                        : Item(id: id, monitor: m, from: to, to: to, opacity: (0, 1), image: image))
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

    private func capture(_ sizes: [WindowID: CGSize]) async -> [WindowID: CGImage]? {
        if sizes.isEmpty { return [:] }
        if content.map({ Set(sizes.keys).isSubset(of: $0.windows.map(\.windowID)) }) != true {
            content = try? await SCShareableContent.current
        }
        guard let windows = content?.windows else { return nil }
        return await withTaskGroup(of: (WindowID, CGImage?).self) { group in
            for window in windows {
                guard let size = sizes[window.windowID] else { continue }
                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int(size.width.rounded()))
                configuration.height = max(1, Int(size.height.rounded()))
                configuration.scalesToFit = true
                configuration.preservesAspectRatio = false
                configuration.showsCursor = false
                configuration.ignoreShadowsSingleWindow = true
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let id = window.windowID
                group.addTask {
                    (id, try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration))
                }
            }
            var images: [WindowID: CGImage] = [:]
            for await case (let id, let image?) in group { images[id] = image }
            return images
        }
    }

    private func show(_ plan: Plan, images: [WindowID: CGImage], for transition: Running) {
        let ready = plan.items.compactMap { item -> Item? in
            var item = item
            item.image = item.image ?? images[item.id]
            return item.image == nil ? nil : item
        }
        guard !ready.isEmpty else { return complete(transition, notify: true) }
        let scales = backingScales()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for items in Dictionary(grouping: ready, by: { $0.monitor.id }).values {
            let monitor = items[0].monitor
            guard let frame = appKitFrame(monitor.frame) else { continue }
            let window = makeOverlay(frame: frame)
            for item in items {
                window.contentView?.layer?.addSublayer(
                    layer(for: item, in: monitor.frame, scale: scales[monitor.id] ?? 2, plan: plan))
            }
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

    private func layer(for item: Item, in monitor: Rect, scale: CGFloat, plan: Plan) -> CALayer {
        func local(_ r: Rect) -> CGRect {
            CGRect(x: r.x - monitor.x, y: monitor.maxY - r.maxY, width: r.w, height: r.h)
        }
        func lerp(_ a: Double, _ b: Double, _ p: Double) -> Double { a + (b - a) * p }
        let start = local(item.from)
        let end = local(item.to)
        let layer = CALayer()
        layer.contents = item.image
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
