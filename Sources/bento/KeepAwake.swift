import IOKit.pwr_mgt

@MainActor
final class KeepAwake {
    private var assertion: IOPMAssertionID?

    var isOn: Bool { assertion != nil }

    func toggle() {
        if let assertion {
            IOPMAssertionRelease(assertion)
            self.assertion = nil
            return
        }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "Bento Keep Awake" as CFString, &id)
        if result == kIOReturnSuccess { assertion = id }
    }

    func stop() {
        if isOn { toggle() }
    }
}
