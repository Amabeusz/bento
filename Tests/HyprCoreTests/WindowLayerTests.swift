import Testing
@testable import HyprCore

@Test func normalAndPanelLayersAreManaged() {
    #expect(isManagedWindowLayer(0))
    #expect(isManagedWindowLayer(3))
    #expect(isManagedWindowLayer(8))
}

@Test func popUpMenuLayerAndAboveAreNotManaged() {
    #expect(!isManagedWindowLayer(101))
    #expect(!isManagedWindowLayer(200))
}
