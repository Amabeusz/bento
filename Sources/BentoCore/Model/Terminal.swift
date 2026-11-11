public func terminalOpenArguments(app: String, home: String) -> [String] {
    ["Terminal", "iTerm", "iTerm2"].contains(app) ? ["-a", app, home] : ["-na", app]
}
