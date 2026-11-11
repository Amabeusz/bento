import Testing
@testable import BentoCore

@Suite struct TerminalTests {
    @Test func openArguments() {
        #expect(terminalOpenArguments(app: "Terminal", home: "/Users/me") == ["-a", "Terminal", "/Users/me"])
        #expect(terminalOpenArguments(app: "iTerm", home: "/Users/me") == ["-a", "iTerm", "/Users/me"])
        #expect(terminalOpenArguments(app: "iTerm2", home: "/Users/me") == ["-a", "iTerm2", "/Users/me"])
        #expect(terminalOpenArguments(app: "Ghostty", home: "/Users/me") == ["-na", "Ghostty"])
        #expect(terminalOpenArguments(app: "WezTerm", home: "/Users/me") == ["-na", "WezTerm"])
    }
}
