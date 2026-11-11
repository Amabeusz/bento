import Testing
@testable import BentoCore

@Suite struct PermissionsTests {
    @Test func accessibilityGatesWindowAndShortcutFeatures() {
        #expect(features(needing: .accessibility) == [.tiling, .shortcuts, .overview, .palette, .paste])
    }

    @Test func screenRecordingGatesOnlyCaptures() {
        #expect(features(needing: .screenRecording) == [.animations, .thumbnails])
    }

    @Test func clipboardHistoryKeepAwakeAndSettingsNeedNoPermission() {
        #expect(Feature.allCases.filter { $0.permission == nil } == [.clipboardHistory, .keepAwake, .launchAtLogin, .settings])
    }

    @Test func pasteFallsBackToCopyWithoutPostEvent() {
        #expect(pasteMode(postEventAllowed: true) == .paste)
        #expect(pasteMode(postEventAllowed: false) == .copyOnly)
    }
}
