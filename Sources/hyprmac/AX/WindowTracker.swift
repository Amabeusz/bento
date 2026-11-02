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
    var onAppGone: () -> Void = {}
    var onFrameChange: (WindowID) -> Void = { _ in }

    private var windows: [WindowID: AXWindow] = [:]
    private var reported: Set<WindowID> = []
    private var observers: [pid_t: AXObserver] = [:]
    private static let appNotifications = [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification]
    private static let windowNotifications = [
        kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification, kAXMovedNotification, kAXResizedNotification,
    ]

    var managedWindows: [AXWindow] {
        reported.compactMap { windows[$0] }
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
        center.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
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
        onAppGone()
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        for w in windows.values where w.pid == pid { forget(w.id) }
    }

    @objc private func appActivated(_ note: Notification) {
        if let id = focusedWindowID() { onFocus(id) }
    }

    @objc private func spaceChanged(_ note: Notification) {
        recheckAll()
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
        guard AXObserverAddNotification(observer, element, kAXUIElementDestroyedNotification as CFString, refcon) == .success
        else { return nil }
        Self.windowNotifications.forEach { _ = AXObserverAddNotification(observer, element, $0 as CFString, refcon) }
        windows[id] = w
        report(w, eligible: isEligible(w))
        return w
    }

    private func isEligible(_ w: AXWindow) -> Bool {
        !w.isMinimized && !w.isFullscreen
    }

    private func report(_ w: AXWindow, eligible: Bool) {
        if eligible, reported.insert(w.id).inserted {
            onAdd(w.info)
        } else if !eligible, reported.remove(w.id) != nil {
            onRemove(w.id)
        }
    }

    private func recheckAll() {
        windows.values.forEach { report($0, eligible: isEligible($0)) }
    }

    private func forget(_ id: WindowID) {
        windows[id] = nil
        if reported.remove(id) != nil { onRemove(id) }
    }

    fileprivate func handle(_ element: AXUIElement, _ notification: String) {
        switch notification {
        case kAXWindowCreatedNotification:
            discover(element)
        case kAXFocusedWindowChangedNotification:
            guard let w = discover(element) else { return }
            report(w, eligible: isEligible(w))
            if reported.contains(w.id) { onFocus(w.id) }
        case kAXUIElementDestroyedNotification:
            if let w = windows.values.first(where: { CFEqual($0.element, element) }) { forget(w.id) }
        case kAXWindowMiniaturizedNotification:
            if let id = windowID(of: element), let w = windows[id] { report(w, eligible: false) }
        case kAXWindowDeminiaturizedNotification:
            if let id = windowID(of: element), let w = windows[id] { report(w, eligible: !w.isFullscreen) }
        case kAXMovedNotification, kAXResizedNotification:
            if let id = windowID(of: element), reported.contains(id) { onFrameChange(id) }
        default:
            break
        }
    }
}
