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
        restoreParkedWindows()
    }

    func configDidChange() {
        reloadFromDisk()
        refreshMenu()
        world?.updateConfig(loader.current)
        applyLayout()
    }

    func startTiling() {
        let tracker = WindowTracker()
        tracker.onAdd = { [weak self] info in self?.world?.addWindow(info); self?.applyLayout() }
        tracker.onRemove = { [weak self] id in self?.world?.removeWindow(id); self?.applyLayout() }
        tracker.onFocus = { [weak self] id in self?.world?.externalFocus(id); self?.applyLayout() }
        tracker.start()
        self.tracker = tracker
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
        applier.apply(world.snapshot())
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
