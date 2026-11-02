import Testing
@testable import HyprCore

@Test func startsWithDefaults() { #expect(ConfigLoader().current == (try! parseConfig(defaultConfigText))) }

@Test func badReloadKeepsPrevious() {
    let l = ConfigLoader(); l.reload(text: "general {\n gaps_in = 4\n}")
    l.reload(text: "general {\n gaps_in = x\n}")
    #expect(l.current.gapsIn == 4); #expect(l.lastError?.line == 2)
}

@Test func goodReloadClearsError() { let l = ConfigLoader(); l.reload(text: "}"); l.reload(text: ""); #expect(l.lastError == nil) }
