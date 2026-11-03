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
    var onReplace: (WindowID, WindowInfo) -> Void = { _, _ in }

    private var windows: [WindowID: AXWindow] = [:]
    private var reported: Set<WindowID> = []
    private var observers: [pid_t: AXObserver] = [:]
    private var retrying: Set<pid_t> = []
    private var hidden: Set<pid_t> = []
    private var lastFrame: [WindowID: Rect] = [:]
    private var seenAt: [WindowID: TimeInterval] = [:]
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
        center.addObserver(self, selector: #selector(appHidden), name: NSWorkspace.didHideApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appUnhidden), name: NSWorkspace.didUnhideApplicationNotification, object: nil)
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
        retrying.remove(pid)
        hidden.remove(pid)
        if let observer = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        for w in windows.values where w.pid == pid { forget(w.id) }
    }

    @objc private func appActivated(_ note: Notification) {
        if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { observe(app) }
        if let id = focusedWindowID() { onFocus(id) }
    }

    @objc private func appHidden(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        onAppGone()
        hidden.insert(app.processIdentifier)
        for w in windows.values where w.pid == app.processIdentifier { report(w, eligible: false) }
    }

    @objc private func appUnhidden(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              hidden.remove(app.processIdentifier) != nil
        else { return }
        recheck(pid: app.processIdentifier)
        if let id = focusedWindowID() { onFocus(id) }
    }

    @objc private func spaceChanged(_ note: Notification) {
        recheckAll()
    }

    private func observe(_ app: NSRunningApplication, attempt: Int = 0) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != getpid(), observers[pid] == nil, !app.isTerminated,
              !retrying.contains(pid)
        else { return }
        var created: AXObserver?
        guard AXObserverCreate(pid, axCallback, &created) == .success, let observer = created else { return }
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let results = Self.appNotifications.map { AXObserverAddNotification(observer, appElement, $0 as CFString, refcon) }
        guard results.allSatisfy({ $0 == .success }) else {
            if attempt < 10 {
                retrying.insert(pid)
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
                    MainActor.assumeIsolated {
                        self?.retrying.remove(pid)
                        self?.observe(app, attempt: attempt + 1)
                    }
                }
            }
            return
        }
        if app.isHidden { hidden.insert(pid) }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
        let elements: [AXUIElement] = appElement.value(kAXWindowsAttribute) ?? []
        elements.forEach { discover($0, settled: true) }
        recheck(pid: pid)
    }

    @discardableResult
    private func discover(_ element: AXUIElement, settled: Bool = false) -> AXWindow? {
        guard let id = windowID(of: element) else { return nil }
        if let known = windows[id] { return known }
        var pid: pid_t = 0
        let role: String? = element.value(kAXRoleAttribute)
        guard AXUIElementGetPid(element, &pid) == .success, role == kAXWindowRole, isManagedWindowLayer(layer(of: id)),
              let observer = observers[pid],
              let app = NSRunningApplication(processIdentifier: pid),
              let w = AXWindow(element: element, pid: pid, app: app.localizedName ?? "")
        else { return nil }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(observer, element, kAXUIElementDestroyedNotification as CFString, refcon) == .success
        else { return nil }
        Self.windowNotifications.forEach { _ = AXObserverAddNotification(observer, element, $0 as CFString, refcon) }
        windows[id] = w
        lastFrame[id] = w.frame
        if !settled {
            seenAt[id] = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.asyncAfter(deadline: .now() + windowSettleTime) { [weak self] in
                MainActor.assumeIsolated { self?.recheck(pid: pid) }
            }
        }
        return w
    }

    private func layer(of id: WindowID) -> Int {
        var value = UnsafeRawPointer(bitPattern: UInt(id))
        let list = CGWindowListCreateDescriptionFromArray(CFArrayCreate(nil, &value, 1, nil)) as? [[String: Any]]
        return (list?.first?[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
    }

    private func settled(_ pid: pid_t) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        return isSettled(windowAges: windows.values.filter { $0.pid == pid }.compactMap { w in seenAt[w.id].map { now - $0 } })
    }

    private func isEligible(_ w: AXWindow, onScreen: Set<WindowID>, shown: [TabCandidate]) -> Bool {
        isManagedWindowLayer(layer(of: w.id)) && !hidden.contains(w.pid) && !w.isMinimized && !w.isFullscreen
            && !isHiddenTab(candidate(w), onScreen: onScreen.contains(w.id), shown: shown)
    }

    private func onScreenIDs() -> Set<WindowID> {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(list.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
    }

    private func candidate(_ w: AXWindow) -> TabCandidate {
        TabCandidate(id: w.id, pid: w.pid, frame: lastFrame[w.id] ?? w.frame)
    }

    private func swapTab(_ swap: TabSwap) {
        guard let new = windows[swap.new] else { return }
        reported.remove(swap.old)
        reported.insert(swap.new)
        onReplace(swap.old, new.info)
    }

    private func recheck(pid: pid_t? = nil) {
        let onScreen = onScreenIDs()
        let checked = windows.values.filter { (pid == nil || $0.pid == pid) && settled($0.pid) }
        checked.forEach { lastFrame[$0.id] = $0.frame }
        let shown = checked.filter { onScreen.contains($0.id) }.map(candidate)
        var lost: [AXWindow] = []
        var gained: [AXWindow] = []
        for w in checked {
            let eligible = isEligible(w, onScreen: onScreen, shown: shown)
            if eligible && !reported.contains(w.id) { gained.append(w) }
            if !eligible && reported.contains(w.id) { lost.append(w) }
        }
        let swaps = pairTabSwaps(lost: lost.map(candidate), gained: gained.map(candidate))
        swaps.forEach(swapTab)
        let swapped = Set(swaps.flatMap { [$0.old, $0.new] })
        for w in lost + gained where !swapped.contains(w.id) { report(w, eligible: gained.contains { $0 === w }) }
    }

    private func recheckSoon(pid: pid_t) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
            MainActor.assumeIsolated { self?.recheck(pid: pid) }
        }
    }

    private func closed(_ w: AXWindow) {
        let siblings = windows.values.filter { $0.pid == w.pid && $0.id != w.id && !reported.contains($0.id) && !$0.isMinimized }
        guard reported.contains(w.id),
              let swap = pairTabSwaps(lost: [candidate(w)], gained: siblings.map(candidate)).first
        else {
            forget(w.id)
            recheckSoon(pid: w.pid)
            return
        }
        swapTab(swap)
        windows[w.id] = nil
        lastFrame[w.id] = nil
        seenAt[w.id] = nil
        recheckSoon(pid: w.pid)
    }

    private func report(_ w: AXWindow, eligible: Bool) {
        if eligible, reported.insert(w.id).inserted {
            onAdd(w.info)
        } else if !eligible, reported.remove(w.id) != nil {
            onRemove(w.id)
        }
    }

    private func recheckAll() {
        recheck()
    }

    private func forget(_ id: WindowID) {
        windows[id] = nil
        lastFrame[id] = nil
        seenAt[id] = nil
        if reported.remove(id) != nil { onRemove(id) }
    }

    fileprivate func handle(_ element: AXUIElement, _ notification: String) {
        switch notification {
        case kAXWindowCreatedNotification:
            guard let w = discover(element) else { return }
            recheck(pid: w.pid)
            recheckSoon(pid: w.pid)
        case kAXFocusedWindowChangedNotification:
            guard let w = discover(element) else { return }
            recheck(pid: w.pid)
            if reported.contains(w.id) { onFocus(w.id) }
        case kAXUIElementDestroyedNotification:
            if let w = windows.values.first(where: { CFEqual($0.element, element) }) { closed(w) }
        case kAXWindowMiniaturizedNotification:
            if let id = windowID(of: element), let w = windows[id] { report(w, eligible: false) }
        case kAXWindowDeminiaturizedNotification:
            if let id = windowID(of: element), let w = windows[id] { report(w, eligible: !w.isFullscreen) }
        case kAXMovedNotification, kAXResizedNotification:
            guard let id = windowID(of: element), let w = windows[id] else { return }
            lastFrame[id] = w.frame
            if reported.contains(id) { onFrameChange(id) }
        default:
            break
        }
    }
}
