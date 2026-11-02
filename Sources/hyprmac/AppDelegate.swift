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

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "hyprmac")

        writeDefaultConfigIfMissing()
        reloadFromDisk()
        watcher = ConfigWatcher(url: configURL) { [weak self] in self?.configDidChange() }

        screenRecordingGranted = CGPreflightScreenCaptureAccess()
        refreshMenu()

        NSApp.activate()
        warnAboutConflictingManagers()
        waitForAccessibility()
    }

    func configDidChange() {
        reloadFromDisk()
        refreshMenu()
    }

    func startTiling() {}

    private func writeDefaultConfigIfMissing() {
        guard !FileManager.default.fileExists(atPath: configURL.path) else { return }
        try? FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? defaultConfigText.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func reloadFromDisk() {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return }
        loader.reload(text: text)
    }

    private func refreshMenu() {
        let menu = NSMenu()
        menu.addItem(item("Reload Config", #selector(reloadConfig)))
        menu.addItem(item("Open Config", #selector(openConfig)))
        if let error = loader.lastError {
            let errorItem = NSMenuItem(title: "Config Error: line \(error.line) — \(error.message)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }
        if !screenRecordingGranted {
            let note = NSMenuItem(title: "Animations off (no Screen Recording)", action: nil, keyEquivalent: "")
            note.isEnabled = false
            menu.addItem(note)
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

    @objc private func reloadConfig() {
        configDidChange()
    }

    @objc private func openConfig() {
        NSWorkspace.shared.open(configURL)
    }

    @objc private func togglePause() {
        isPaused.toggle()
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
