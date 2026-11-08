import AppKit
import ApplicationServices
import BentoCore

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

func windowID(of element: AXUIElement) -> WindowID? {
    var id: CGWindowID = 0
    guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
    return id
}

extension AXUIElement {
    func value<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    func set(_ attribute: String, _ value: CFTypeRef) {
        _ = AXUIElementSetAttributeValue(self, attribute as CFString, value)
    }

    func isSettable(_ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(self, attribute as CFString, &settable) == .success else { return false }
        return settable.boolValue
    }

    func perform(_ action: String) {
        _ = AXUIElementPerformAction(self, action as CFString)
    }

    func axValue<T: BitwiseCopyable>(_ attribute: String, _ type: AXValueType, _ empty: T) -> T? {
        guard let raw: CFTypeRef = value(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = empty
        guard AXValueGetValue(raw as! AXValue, type, &result) else { return nil }
        return result
    }
}

@MainActor
final class AXWindow {
    let element: AXUIElement
    let id: WindowID
    let pid: pid_t
    let app: String

    init?(element: AXUIElement, pid: pid_t, app: String) {
        guard let id = windowID(of: element) else { return nil }
        self.element = element
        self.id = id
        self.pid = pid
        self.app = app
    }

    var frame: Rect {
        get {
            let p = element.axValue(kAXPositionAttribute, .cgPoint, CGPoint.zero) ?? .zero
            let s = element.axValue(kAXSizeAttribute, .cgSize, CGSize.zero) ?? .zero
            return Rect(x: p.x, y: p.y, w: s.width, h: s.height)
        }
        set {
            var position = CGPoint(x: newValue.x, y: newValue.y)
            var size = CGSize(width: newValue.w, height: newValue.h)
            guard let p = AXValueCreate(.cgPoint, &position), let s = AXValueCreate(.cgSize, &size) else { return }
            element.set(kAXPositionAttribute, p)
            element.set(kAXSizeAttribute, s)
            element.set(kAXPositionAttribute, p)
        }
    }

    var title: String {
        element.value(kAXTitleAttribute) ?? ""
    }

    var isDialog: Bool {
        let fullscreenButton: AXUIElement? = element.value(kAXFullScreenButtonAttribute)
        let fullscreenEnabled: Bool = fullscreenButton?.value(kAXEnabledAttribute) ?? false
        return looksLikeDialog(
            subrole: element.value(kAXSubroleAttribute),
            resizable: element.isSettable(kAXSizeAttribute),
            hasFullscreenButton: fullscreenEnabled,
            isModal: element.value(kAXModalAttribute) ?? false)
    }

    var isPopup: Bool {
        let buttons = [kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXZoomButtonAttribute, kAXFullScreenButtonAttribute]
        return looksLikePopup(
            subrole: element.value(kAXSubroleAttribute),
            hasWindowButtons: buttons.contains { (element.value($0) as AXUIElement?) != nil })
    }

    var isMinimized: Bool {
        element.value(kAXMinimizedAttribute) ?? false
    }

    var isFullscreen: Bool {
        element.value("AXFullScreen") ?? false
    }

    var info: WindowInfo {
        WindowInfo(id: id, app: app, title: title, isDialog: isDialog, frame: frame)
    }

    func raiseAndFocus() {
        NSRunningApplication(processIdentifier: pid)?.activate()
        element.set(kAXMainAttribute, kCFBooleanTrue)
        element.perform(kAXRaiseAction)
    }

    func close() {
        let button: AXUIElement? = element.value(kAXCloseButtonAttribute)
        button?.perform(kAXPressAction)
    }
}
