import Testing
@testable import BentoCore

@Suite struct PermissionsTests {
    @Test func accessibilityGatesWindowAndShortcutFeatures() {
        #expect(Feature.allCases.filter { $0.permission == .accessibility } == [.tiling, .shortcuts, .overview, .palette, .paste])
    }

    @Test func screenRecordingGatesOnlyCaptures() {
        #expect(Feature.allCases.filter { $0.permission == .screenRecording } == [.animations, .thumbnails])
    }

    @Test func clipboardHistoryKeepAwakeAndSettingsNeedNoPermission() {
        #expect(Feature.allCases.filter { $0.permission == nil } == [.clipboardHistory, .keepAwake, .launchAtLogin, .settings])
    }

    @Test func pasteFallsBackToCopyWithoutPostEvent() {
        #expect(pasteMode(postEventAllowed: true) == .paste)
        #expect(pasteMode(postEventAllowed: false) == .copyOnly)
    }
}
