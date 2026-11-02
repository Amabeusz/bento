import AppKit
import HyprCore

@MainActor
final class Effects {
    private let tracker: WindowTracker

    init(tracker: WindowTracker) {
        self.tracker = tracker
    }

    func run(_ e: SideEffect) {
        switch e {
        case .exec(let command):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            try? process.run()
        case .launchApp(let name):
            guard let url = applicationURL(name) else { return }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        case .closeWindow(let id):
            tracker.window(id)?.close()
        case .focusWindow(let id):
            tracker.window(id)?.raiseAndFocus()
        case .focusNothing:
            let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
            if let finder, !tracker.allWindows.contains(where: { $0.pid == finder.processIdentifier }) {
                finder.activate()
            } else {
                NSApp.activate()
            }
        case .warpCursor(let p):
            CGWarpMouseCursorPosition(CGPoint(x: p.x, y: p.y))
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    private func applicationURL(_ name: String) -> URL? {
        if name.contains("."), let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return url
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications", "/System/Applications", "\(home)/Applications"]
            .map { URL(fileURLWithPath: "\($0)/\(name).app") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
