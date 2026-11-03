import Testing
@testable import HyprCore

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
