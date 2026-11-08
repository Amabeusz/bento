import Testing
@testable import BentoCore

@Test func normalAndPanelLayersAreManaged() {
    #expect(isManagedWindowLayer(0))
    #expect(isManagedWindowLayer(3))
    #expect(isManagedWindowLayer(8))
}

@Test func popUpMenuLayerAndAboveAreNotManaged() {
    #expect(!isManagedWindowLayer(101))
    #expect(!isManagedWindowLayer(200))
}

@Test func appWithANewWindowWaitsUntilItSettles() {
    #expect(!isSettled(windowAges: [5, 0]))
    #expect(!isSettled(windowAges: [5, windowSettleTime / 2]))
    #expect(isSettled(windowAges: [5, windowSettleTime]))
}

@Test func appWithoutNewWindowsIsSettled() {
    #expect(isSettled(windowAges: []))
    #expect(isSettled(windowAges: [5, 10]))
}
