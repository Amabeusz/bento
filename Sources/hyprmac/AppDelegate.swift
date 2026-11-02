import AppKit
import ApplicationServices
import HyprCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let loader = ConfigLoader()
    var world: World?
    private(set) var isPaused = false

    private let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/hyprmac/hyprmac.conf")
    private var statusItem: NSStatusItem?
    private var watcher: ConfigWatcher?
    private var accessibilityTimer: Timer?
    private var screenRecordingGranted = true
    private var ioErrorMessage: String?
    private var tracker: WindowTracker?
    private var applier: Applier?
    private var signalSources: [DispatchSourceSignal] = []
    private var effects: Effects?
    private var eventTap: EventTap?
    private var keyBinds: [KeyChord: Action] = [:]
    private var unknownKeys: [String] = []
    private var drag: Drag?
    private let borders = BorderManager()
    private lazy var bars = BarManager { [weak self] number in self?.selectWorkspace(number) }

    private struct Drag {
        let id: WindowID
        let button: Int
        let action: MouseAction
        let isFloating: Bool
        var frame: Rect
        var last: Point
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "hyprmac")

        writeDefaultConfigIfMissing()
        reloadFromDisk()
        watcher = ConfigWatcher(url: configURL) { [weak self] in self?.configDidChange() }

        screenRecordingGranted = CGPreflightScreenCaptureAccess()
        refreshMenu()

        installSignalHandlers()
        NSApp.activate()
        warnAboutConflictingManagers()
        waitForAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        borders.removeAll()
        bars.removeAll()
        restoreParkedWindows()
    }

    func configDidChange() {
        reloadFromDisk()
        refreshMenu()
        world?.updateConfig(loader.current)
        eventTap?.watchesMouseMoved = loader.current.followMouse
        applyLayout()
    }

    func startTiling() {
        let tracker = WindowTracker()
        tracker.onAdd = { [weak self] info in self?.world?.addWindow(info); self?.applyLayout() }
        tracker.onRemove = { [weak self] id in self?.world?.removeWindow(id); self?.applyLayout() }
        tracker.onFocus = { [weak self] id in self?.world?.externalFocus(id); self?.applyLayout() }
        tracker.start()
        self.tracker = tracker
        effects = Effects(tracker: tracker)
        let eventTap = EventTap(
            onKey: { [weak self] mods, code in self?.handleKey(mods, code) ?? false },
            onMouse: { [weak self] event in self?.handleMouse(event) ?? false })
        eventTap.watchesMouseMoved = loader.current.followMouse
        eventTap.start()
        self.eventTap = eventTap
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !isPaused { buildWorld() }
    }

    private func buildWorld() {
        guard let tracker else { return }
        restoreParkedWindows()
        let world = World(config: loader.current)
        world.setMonitors(monitorInfos())
        tracker.managedWindows.sorted { $0.id < $1.id }.forEach { world.addWindow($0.info) }
        if let id = tracker.focusedWindowID() { world.externalFocus(id) }
        self.world = world
        applier = Applier(tracker: tracker)
        applyLayout()
    }

    private func applyLayout() {
        guard let world, let applier else { return }
        let snapshot = world.snapshot()
        applier.apply(snapshot)
        borders.update(snapshot, config: loader.current)
        bars.update(snapshot, monitors: monitorInfos(), config: loader.current)
    }

    private func selectWorkspace(_ number: Int) {
        guard !isPaused, let world else { return }
        world.perform(.workspace(number)).forEach { effects?.run($0) }
        applyLayout()
    }

    private func handleKey(_ mods: Modifiers, _ code: CGKeyCode) -> Bool {
        guard !isPaused, let world, let action = keyBinds[KeyChord(mods: mods, code: code)] else { return false }
        world.perform(action).forEach { effects?.run($0) }
        applyLayout()
        return true
    }

    private func handleMouse(_ event: MouseEvent) -> Bool {
        guard !isPaused, let world else {
            drag = nil
            return false
        }
        switch event {
        case .down(let button, let mods, let p):
            drag = nil
            guard let bind = loader.current.mouseBinds.first(where: { $0.mods == mods && $0.button == button }),
                  let hit = managedWindow(at: p, in: world.snapshot())
            else { return false }
            drag = Drag(id: hit.id, button: button, action: bind.action, isFloating: hit.isFloating, frame: hit.frame, last: p)
            return true
        case .dragged(let button, let p):
            guard var d = drag, d.button == button else { return false }
            let dx = p.x - d.last.x
            let dy = p.y - d.last.y
            d.last = p
            switch (d.action, d.isFloating) {
            case (.move, true):
                d.frame.x += dx
                d.frame.y += dy
                world.setFloatingFrame(d.id, d.frame)
                applyLayout()
            case (.move, false):
                d.frame.x += dx
                d.frame.y += dy
                tracker?.window(d.id)?.frame = d.frame
                borders.updateFrame(d.id, d.frame)
            case (.resize, true):
                d.frame.w += dx
                d.frame.h += dy
                world.setFloatingFrame(d.id, d.frame)
                applyLayout()
            case (.resize, false):
                world.resizeTiled(d.id, dx: dx, dy: dy)
                applyLayout()
            }
            drag = d
            return true
        case .up(let button, let p):
            guard let d = drag, d.button == button else { return false }
            drag = nil
            if d.action == .move && !d.isFloating {
                world.dropTiled(d.id, at: p)
                applyLayout()
                if case .tiled(let r) = world.snapshot().placements[d.id] { tracker?.window(d.id)?.frame = r }
            }
            return true
        case .moved(let p):
            guard loader.current.followMouse else { return false }
            let snapshot = world.snapshot()
            guard let hit = managedWindow(at: p, in: snapshot), hit.id != snapshot.focused else { return false }
            world.externalFocus(hit.id)
            tracker?.window(hit.id)?.raiseAndFocus()
            applyLayout()
            return false
        }
    }

    private func managedWindow(at p: Point, in s: LayoutSnapshot) -> (id: WindowID, frame: Rect, isFloating: Bool)? {
        var floating: [(WindowID, Rect)] = []
        var tiled: [(WindowID, Rect)] = []
        for (id, placement) in s.placements {
            switch placement {
            case .floating(let r) where r.contains(p): floating.append((id, r))
            case .tiled(let r) where r.contains(p): tiled.append((id, r))
            default: break
            }
        }
        if let f = floating.first(where: { $0.0 == s.focused }) ?? floating.first { return (f.0, f.1, true) }
        return (tiled.first { $0.0 == s.focused } ?? tiled.first).map { ($0.0, $0.1, false) }
    }

    private func restoreParkedWindows() {
        let monitors = monitorInfos()
        guard let tracker, let main = monitors.first else { return }
        for w in tracker.allWindows where isParked(w.frame, monitors: monitors) {
            w.frame = recoveryFrame(for: w.frame, on: main)
        }
    }

    private func installSignalHandlers() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    self?.restoreParkedWindows()
                    exit(0)
                }
            }
            source.resume()
            signalSources.append(source)
        }
    }

    @objc private func screensChanged() {
        world?.setMonitors(monitorInfos())
        applyLayout()
    }

    private func writeDefaultConfigIfMissing() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            try FileManager.default.createDirectory(
                at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try defaultConfigText.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            ioErrorMessage = "cannot write default config: \(error.localizedDescription)"
        }
    }

    private func reloadFromDisk() {
        do {
            let text = try String(contentsOf: configURL, encoding: .utf8)
            ioErrorMessage = nil
            loader.reload(text: text)
        } catch {
            ioErrorMessage = "cannot read config: \(error.localizedDescription)"
        }
        (keyBinds, unknownKeys) = keyTable(for: loader.current.keyBinds)
    }

    private func refreshMenu() {
        let menu = NSMenu()
        menu.addItem(item("Reload Config", #selector(reloadConfig)))
        menu.addItem(item("Open Config", #selector(openConfig)))
        if let ioErrorMessage {
            menu.addItem(disabledItem("Config Error: \(ioErrorMessage)"))
        } else if let error = loader.lastError {
            menu.addItem(disabledItem("Config Error: line \(error.line) — \(error.message)"))
        }
        for key in unknownKeys {
            menu.addItem(disabledItem("Config Error: unknown key '\(key)'"))
        }
        if !screenRecordingGranted {
            menu.addItem(disabledItem("Animations off (no Screen Recording)"))
        }
        menu.addItem(.separator())
        menu.addItem(item(isPaused ? "Resume Tiling" : "Pause Tiling", #selector(togglePause)))
        let login = item("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Quit hyprmac", #selector(quit), key: "q"))
        statusItem?.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: key)
        menuItem.target = self
        return menuItem
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    @objc private func reloadConfig() {
        configDidChange()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(configURL)
    }

    @objc private func togglePause() {
        isPaused.toggle()
        if isPaused {
            borders.removeAll()
            bars.removeAll()
            restoreParkedWindows()
            world = nil
            applier = nil
        } else {
            buildWorld()
        }
        refreshMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func warnAboutConflictingManagers() {
        let conflicts = NSWorkspace.shared.runningApplications.compactMap { app -> String? in
            if app.localizedName == "OmniWM" || app.localizedName == "Rectangle" { return app.localizedName }
            if app.bundleIdentifier == "com.knollsoft.Rectangle" { return "Rectangle" }
            return nil
        }
        guard !conflicts.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Another window manager is running"
        alert.informativeText = "\(Set(conflicts).sorted().joined(separator: ", ")) will fight with hyprmac over window positions. Quit it and relaunch hyprmac."
        alert.runModal()
    }

    private func waitForAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startTiling()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Accessibility permission needed"
        alert.informativeText = "hyprmac needs Accessibility access to move and resize windows. Grant it in System Settings > Privacy & Security > Accessibility. Tiling starts automatically once it is granted."
        alert.runModal()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollAccessibility() }
        }
    }

    private func pollAccessibility() {
        guard AXIsProcessTrusted() else { return }
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        startTiling()
    }
}

@MainActor
func monitorInfos() -> [MonitorInfo] {
    guard let primaryHeight = NSScreen.screens.first?.frame.height else { return [] }
    func flip(_ r: NSRect) -> Rect {
        Rect(x: r.minX, y: primaryHeight - r.maxY, w: r.width, h: r.height)
    }
    return NSScreen.screens.compactMap { screen in
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        let id = CGDirectDisplayID(number.uint32Value)
        return MonitorInfo(id: id, frame: flip(screen.frame), usable: flip(screen.visibleFrame), isBuiltin: CGDisplayIsBuiltin(id) != 0)
    }
}

@MainActor
func appKitFrame(_ r: Rect) -> NSRect? {
    guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
    return NSRect(x: r.x, y: primaryHeight - (r.y + r.h), width: r.w, height: r.h)
}
