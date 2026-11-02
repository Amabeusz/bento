import AppKit
import ApplicationServices
import HyprCore

private func axCallback(
    _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let tracker = Unmanaged<WindowTracker>.fromOpaque(refcon).takeUnretainedValue()
    nonisolated(unsafe) let element = element
    let name = notification as String
    MainActor.assumeIsolated { tracker.handle(element, name) }
}

@MainActor
final class WindowTracker {
    var onAdd: (WindowInfo) -> Void = { _ in }
    var onRemove: (WindowID) -> Void = { _ in }
    var onFocus: (WindowID) -> Void = { _ in }

    private var windows: [WindowID: AXWindow] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private static let appNotifications = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification]
    private static let windowNotifications = [
        kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
    ]

    var managedWindows: [AXWindow] {
        windows.values.filter { !$0.isMinimized && !$0.isFullscreen }
    }

    var allWindows: [AXWindow] {
        Array(windows.values)
    }

    func start() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appLaunched), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appTerminated), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appActivated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.runningApplications.forEach { observe($0) }
    }

    func window(_ id: WindowID) -> AXWindow? {
        windows[id]
    }

    func focusedWindowID() -> WindowID? {
        guard let app = NSWorkspace.shared.frontmostApplication, observers[app.processIdentifier] != nil else { return nil }
        let focused: AXUIElement? = AXUIElementCreateApplication(app.processIdentifier).value(kAXFocusedWindowAttribute)
        return focused.flatMap(windowID(of:)).flatMap { windows[$0]?.id }
    }

    @objc private func appLaunched(_ note: Notification) {
        if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { observe(app) }
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let pid = app.processIdentifier
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        for w in windows.values where w.pid == pid {
            windows[w.id] = nil
            onRemove(w.id)
        }
    }

    @objc private func appActivated(_ note: Notification) {
        if let id = focusedWindowID() { onFocus(id) }
    }

    private func observe(_ app: NSRunningApplication, attempt: Int = 0) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != getpid(), observers[pid] == nil, !app.isTerminated else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, axCallback, &created) == .success, let observer = created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let results = Self.appNotifications.map { AXObserverAddNotification(observer, appElement, $0 as CFString, refcon) }
        guard results.allSatisfy({ $0 == .success }) else {
            if attempt < 10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
                    MainActor.assumeIsolated { self?.observe(app, attempt: attempt + 1) }
                }
            }
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
        let elements: [AXUIElement] = appElement.value(kAXWindowsAttribute) ?? []
        elements.forEach { discover($0) }
    }

    @discardableResult
    private func discover(_ element: AXUIElement) -> AXWindow? {
        guard let id = windowID(of: element) else { return nil }
        if let known = windows[id] { return known }
        var pid: pid_t = 0
        let role: String? = element.value(kAXRoleAttribute)
        guard AXUIElementGetPid(element, &pid) == .success, role == kAXWindowRole, let observer = observers[pid],
              let app = NSRunningApplication(processIdentifier: pid),
              let w = AXWindow(element: element, pid: pid, app: app.localizedName ?? "")
        else { return nil }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        Self.windowNotifications.forEach { _ = AXObserverAddNotification(observer, element, $0 as CFString, refcon) }
        windows[id] = w
        if !w.isMinimized && !w.isFullscreen { onAdd(w.info) }
        return w
    }

    fileprivate func handle(_ element: AXUIElement, _ notification: String) {
        switch notification {
        case kAXWindowCreatedNotification:
            discover(element)
        case kAXFocusedWindowChangedNotification:
            if let w = discover(element), !w.isMinimized, !w.isFullscreen { onFocus(w.id) }
        case kAXUIElementDestroyedNotification:
            guard let w = windows.values.first(where: { CFEqual($0.element, element) }) else { return }
            windows[w.id] = nil
            onRemove(w.id)
        case kAXWindowMiniaturizedNotification:
            if let id = windowID(of: element), windows[id] != nil { onRemove(id) }
        case kAXWindowDeminiaturizedNotification:
            if let id = windowID(of: element), let w = windows[id] { onAdd(w.info) }
        default:
            break
        }
    }
}
