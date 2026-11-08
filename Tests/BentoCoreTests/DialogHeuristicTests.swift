import Testing
@testable import BentoCore

@Test func normalWindowIsNotADialog() {
    #expect(!looksLikeDialog(subrole: "AXStandardWindow", resizable: true, hasFullscreenButton: true, isModal: false))
}

@Test func windowWithoutFullscreenButtonIsADialog() {
    #expect(looksLikeDialog(subrole: "AXStandardWindow", resizable: true, hasFullscreenButton: false, isModal: false))
}

@Test func modalWindowIsADialog() {
    #expect(looksLikeDialog(subrole: "AXStandardWindow", resizable: true, hasFullscreenButton: true, isModal: true))
}

@Test func otherSubroleIsADialog() {
    #expect(looksLikeDialog(subrole: "AXDialog", resizable: true, hasFullscreenButton: true, isModal: false))
    #expect(looksLikeDialog(subrole: nil, resizable: true, hasFullscreenButton: true, isModal: false))
}

@Test func fixedSizeWindowIsADialog() {
    #expect(looksLikeDialog(subrole: "AXStandardWindow", resizable: false, hasFullscreenButton: true, isModal: false))
}

@Test func buttonlessUnknownWindowIsAPopup() {
    #expect(looksLikePopup(subrole: "AXUnknown", hasWindowButtons: false))
}

@Test func windowsWithButtonsOrAWindowSubroleAreNotPopups() {
    #expect(!looksLikePopup(subrole: "AXUnknown", hasWindowButtons: true))
    #expect(!looksLikePopup(subrole: "AXStandardWindow", hasWindowButtons: true))
    #expect(!looksLikePopup(subrole: "AXDialog", hasWindowButtons: true))
    #expect(!looksLikePopup(subrole: "AXDialog", hasWindowButtons: false))
}
