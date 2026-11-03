public struct RGBA: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(hex: UInt32) {
        self.init(
            r: Double((hex >> 24) & 0xff) / 255,
            g: Double((hex >> 16) & 0xff) / 255,
            b: Double((hex >> 8) & 0xff) / 255,
            a: Double(hex & 0xff) / 255
        )
    }
}

public struct Gradient: Equatable, Sendable {
    public var colors: [RGBA]
    public var angleDegrees: Double

    public init(colors: [RGBA], angleDegrees: Double) {
        self.colors = colors
        self.angleDegrees = angleDegrees
    }
}

public struct Modifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let ctrl = Modifiers(rawValue: 1 << 0)
    public static let alt = Modifiers(rawValue: 1 << 1)
    public static let shift = Modifiers(rawValue: 1 << 2)
    public static let cmd = Modifiers(rawValue: 1 << 3)
}

public enum Direction: String, Sendable {
    case left = "l"
    case right = "r"
    case up = "u"
    case down = "d"
}

public enum Action: Equatable, Sendable {
    case exec(String)
    case focusOrLaunch(String)
    case moveFocus(Direction)
    case moveWindow(Direction)
    case workspace(Int)
    case moveToWorkspace(Int)
    case moveCurrentWorkspaceToMonitor
    case resizeActive(dx: Double, dy: Double)
    case toggleSplit
    case fullscreen
    case toggleFloating
    case killActive
}

public enum MouseAction: Equatable, Sendable {
    case move
    case resize
}

public struct KeyBind: Equatable, Sendable {
    public var mods: Modifiers
    public var key: String
    public var action: Action

    public init(mods: Modifiers, key: String, action: Action) {
        self.mods = mods
        self.key = key
        self.action = action
    }
}

public struct MouseBind: Equatable, Sendable {
    public var mods: Modifiers
    public var button: Int
    public var action: MouseAction

    public init(mods: Modifiers, button: Int, action: MouseAction) {
        self.mods = mods
        self.button = button
        self.action = action
    }
}

public struct CubicBezierSpec: Equatable, Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public struct AnimationSpec: Equatable, Sendable {
    public var enabled: Bool
    public var duration: Double
    public var curve: String
    public var style: String?

    public init(enabled: Bool, duration: Double, curve: String, style: String? = nil) {
        self.enabled = enabled
        self.duration = duration
        self.curve = curve
        self.style = style
    }
}

public enum MonitorSelector: String, Sendable {
    case builtin
    case external
}

public struct WindowRule: Equatable, Sendable {
    public var appPattern: String?
    public var titlePattern: String?

    public init(appPattern: String? = nil, titlePattern: String? = nil) {
        self.appPattern = appPattern
        self.titlePattern = titlePattern
    }
}

public struct Config: Equatable, Sendable {
    public var gapsIn = 10.0
    public var gapsOut = Insets(all: 12)
    public var borderSize = 2.0
    public var borderSizeInactive: Double?
    public var rounding = 16.0
    public var activeBorder = Gradient(
        colors: [RGBA(hex: 0xf5c2e7ff), RGBA(hex: 0xcba6f7ff), RGBA(hex: 0x89b4faff)],
        angleDegrees: 135
    )
    public var inactiveBorder = Gradient(colors: [RGBA(hex: 0x585b70aa)], angleDegrees: 0)
    public var barEnabled = true
    public var barHeight = 30.0
    public var barFontSize = 13.0
    public var barFont = "system"
    public var barMarginTop = 4.0
    public var barMarginBottom = 4.0
    public var barPadding: Double?
    public var barRounding: Double?
    public var barBackground = RGBA(hex: 0x00000000)
    public var barActive = RGBA(hex: 0xf5c2e7ff)
    public var barOtherMonitor = RGBA(hex: 0xcba6f7ff)
    public var barText = RGBA(hex: 0xcdd6f4ff)
    public var barTextActive = RGBA(hex: 0x1e1e2eff)
    public var barTextEmpty = RGBA(hex: 0x6c7086ff)
    public var barError = RGBA(hex: 0xf38ba8ff)
    public var followMouse = false
    public var warpCursor = true
    public var animationsEnabled = true
    public var beziers: [String: CubicBezierSpec] = [
        "linear": CubicBezierSpec(x1: 0, y1: 0, x2: 1, y2: 1),
        "default": CubicBezierSpec(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1),
        "smooth": CubicBezierSpec(x1: 0.05, y1: 0.9, x2: 0.1, y2: 1.05),
    ]
    public var animations: [String: AnimationSpec] = [
        "windows": AnimationSpec(enabled: true, duration: 0.3, curve: "smooth"),
        "workspaces": AnimationSpec(enabled: true, duration: 0.3, curve: "smooth", style: "slide"),
        "border": AnimationSpec(enabled: true, duration: 0.5, curve: "default"),
    ]
    public var startupWorkspace: [MonitorSelector: Int] = [.builtin: 1, .external: 1]
    public var keyBinds: [KeyBind] = []
    public var mouseBinds: [MouseBind] = []
    public var floatRules: [WindowRule] = []

    public init() {}

    public func borderSize(isFocused: Bool) -> Double {
        isFocused ? borderSize : borderSizeInactive ?? borderSize
    }
}
