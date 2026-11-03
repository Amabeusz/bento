import ApplicationServices
import CoreGraphics
import Foundation
import HyprCore

enum MouseEvent: Sendable {
    case down(button: Int, mods: Modifiers, at: Point)
    case dragged(button: Int, at: Point)
    case up(button: Int, at: Point)
    case moved(at: Point)
}

enum TapEvent: Sendable {
    case key(KeyChord)
    case mouse(MouseEvent)
    case permissions(PermissionChange)
}

struct MouseChord: Hashable, Sendable {
    var mods: Modifiers
    var button: Int
}

private func tapCallback(
    _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type, event) ? nil : Unmanaged.passUnretained(event)
}

private struct PortHandoff: @unchecked Sendable {
    let port: CFMachPort
}

final class EventTap: @unchecked Sendable {
    static let leftButton = 272
    static let rightButton = 273
    private static let types: [CGEventType] = [
        .keyDown, .leftMouseDown, .leftMouseDragged, .leftMouseUp,
        .rightMouseDown, .rightMouseDragged, .rightMouseUp,
    ]

    private let onEvent: @MainActor @Sendable (TapEvent) -> Void
    private let lock = NSLock()
    private var chords: Set<KeyChord> = []
    private var mouseBinds: Set<MouseChord> = []
    private var paused = false
    private var followMouse = false
    private var gesture: Int?
    private var port: CFMachPort?
    private var gate = InputPermissionGate()

    init(onEvent: @escaping @MainActor @Sendable (TapEvent) -> Void) {
        self.onEvent = onEvent
    }

    var isRunning: Bool {
        lock.withLock { port != nil }
    }

    func configure(chords: Set<KeyChord>, mouseBinds: Set<MouseChord>, followMouse: Bool, paused: Bool) {
        let restart = lock.withLock {
            self.chords = chords
            self.mouseBinds = mouseBinds
            self.paused = paused
            let changed = port != nil && self.followMouse != followMouse
            self.followMouse = followMouse
            return changed
        }
        if restart {
            stop()
            start()
        }
    }

    @discardableResult
    func start() -> Bool {
        let types = lock.withLock { followMouse } ? Self.types + [.mouseMoved] : Self.types
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: tapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        lock.withLock { self.port = port }
        let handoff = PortHandoff(port: port)
        let thread = Thread {
            let port = handoff.port
            guard let source = CFMachPortCreateRunLoopSource(nil, port, 0) else { return }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            let check = CFRunLoopTimerCreateWithHandler(nil, CFAbsoluteTimeGetCurrent() + 0.5, 0.5, 0, 0) { [weak self] timer in
                guard let self, self.isCurrent(port) else {
                    CFRunLoopTimerInvalidate(timer)
                    CFRunLoopStop(CFRunLoopGetCurrent())
                    return
                }
                self.checkPermissions(port)
            }
            CFRunLoopAddTimer(CFRunLoopGetCurrent(), check, .commonModes)
            CGEvent.tapEnable(tap: port, enable: self.lock.withLock { self.gate.allowed })
            CFRunLoopRun()
        }
        thread.name = "hyprmac event tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    private func stop() {
        let port = lock.withLock {
            defer { self.port = nil }
            return self.port
        }
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        CFMachPortInvalidate(port)
    }

    private func isCurrent(_ port: CFMachPort) -> Bool {
        lock.withLock { self.port === port }
    }

    private func checkPermissions(_ port: CFMachPort) {
        let accessibility = AXIsProcessTrusted()
        let postEvent = CGPreflightPostEventAccess()
        guard let change = lock.withLock({ gate.update(accessibility: accessibility, postEvent: postEvent) }) else { return }
        CGEvent.tapEnable(tap: port, enable: change == .regained)
        send(.permissions(change))
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let p = Point(x: event.location.x, y: event.location.y)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port = lock.withLock({ gate.allowed ? port : nil }) { CGEvent.tapEnable(tap: port, enable: true) }
            return false
        case .keyDown:
            let chord = KeyChord(
                mods: modifiers(from: event.flags), code: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)))
            guard lock.withLock({ !paused && chords.contains(chord) }) else { return false }
            send(.key(chord))
            return true
        case .leftMouseDown, .rightMouseDown:
            let button = type == .leftMouseDown ? Self.leftButton : Self.rightButton
            let mods = modifiers(from: event.flags)
            let bound = lock.withLock {
                gesture = nil
                guard !paused, mouseBinds.contains(MouseChord(mods: mods, button: button)) else { return false }
                gesture = button
                return true
            }
            guard bound else { return false }
            send(.mouse(.down(button: button, mods: mods, at: p)))
            return true
        case .leftMouseDragged, .rightMouseDragged:
            let button = type == .leftMouseDragged ? Self.leftButton : Self.rightButton
            guard lock.withLock({ gesture == button }) else { return false }
            send(.mouse(.dragged(button: button, at: p)))
            return true
        case .leftMouseUp, .rightMouseUp:
            let button = type == .leftMouseUp ? Self.leftButton : Self.rightButton
            let ended = lock.withLock {
                guard gesture == button else { return false }
                gesture = nil
                return true
            }
            guard ended else { return false }
            send(.mouse(.up(button: button, at: p)))
            return true
        case .mouseMoved:
            send(.mouse(.moved(at: p)))
            return false
        default:
            return false
        }
    }

    private func send(_ event: TapEvent) {
        let onEvent = onEvent
        DispatchQueue.main.async { onEvent(event) }
    }
}
