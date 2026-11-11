public enum Permission: String, CaseIterable, Sendable {
    case accessibility = "Accessibility", screenRecording = "Screen Recording"
}

public enum Feature: String, CaseIterable, Sendable {
    case tiling = "Tiling and moving windows"
    case shortcuts = "Keyboard and mouse shortcuts"
    case overview = "Window overview"
    case palette = "Command palette"
    case paste = "Pasting from clipboard history"
    case animations = "Workspace animations"
    case thumbnails = "Window thumbnails in the overview"
    case clipboardHistory = "Clipboard history"
    case keepAwake = "Keep Awake"
    case launchAtLogin = "Launch at Login"
    case settings = "Settings"

    public var permission: Permission? {
        switch self {
        case .tiling, .shortcuts, .overview, .palette, .paste: .accessibility
        case .animations, .thumbnails: .screenRecording
        case .clipboardHistory, .keepAwake, .launchAtLogin, .settings: nil
        }
    }
}

public enum PasteMode: Equatable, Sendable { case paste, copyOnly }

public func pasteMode(postEventAllowed: Bool) -> PasteMode {
    postEventAllowed ? .paste : .copyOnly
}
