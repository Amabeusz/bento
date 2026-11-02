import CoreGraphics
import HyprCore

enum MouseEvent {
    case down(button: Int, mods: Modifiers, at: Point)
    case dragged(button: Int, at: Point)
    case up(button: Int, at: Point)
    case moved(at: Point)
}

private func tapCallback(
    _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
    nonisolated(unsafe) let event = event
    let swallow = MainActor.assumeIsolated { tap.handle(type, event) }
    return swallow ? nil : Unmanaged.passUnretained(event)
}

@MainActor
final class EventTap {
    private static let leftButton = 272
    private static let rightButton = 273
    private static let types: [CGEventType] = [
        .keyDown, .leftMouseDown, .leftMouseDragged, .leftMouseUp,
        .rightMouseDown, .rightMouseDragged, .rightMouseUp,
    ]

    private let onKey: (Modifiers, CGKeyCode) -> Bool
    private let onMouse: (MouseEvent) -> Bool
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    var watchesMouseMoved = false {
        didSet {
            guard watchesMouseMoved != oldValue, port != nil else { return }
            stop()
            start()
        }
    }

    init(onKey: @escaping (Modifiers, CGKeyCode) -> Bool, onMouse: @escaping (MouseEvent) -> Bool) {
        self.onKey = onKey
        self.onMouse = onMouse
    }

    func start() {
        let types = watchesMouseMoved ? Self.types + [.mouseMoved] : Self.types
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: tapCallback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        self.port = port
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let p = Point(x: event.location.x, y: event.location.y)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return false
        case .keyDown:
            return onKey(modifiers(from: event.flags), CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)))
        case .leftMouseDown:
            return onMouse(.down(button: Self.leftButton, mods: modifiers(from: event.flags), at: p))
        case .rightMouseDown:
            return onMouse(.down(button: Self.rightButton, mods: modifiers(from: event.flags), at: p))
        case .leftMouseDragged:
            return onMouse(.dragged(button: Self.leftButton, at: p))
        case .rightMouseDragged:
            return onMouse(.dragged(button: Self.rightButton, at: p))
        case .leftMouseUp:
            return onMouse(.up(button: Self.leftButton, at: p))
        case .rightMouseUp:
            return onMouse(.up(button: Self.rightButton, at: p))
        case .mouseMoved:
            return onMouse(.moved(at: p))
        default:
            return false
        }
    }
}
