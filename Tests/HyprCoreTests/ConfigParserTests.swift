import Testing
@testable import HyprCore

@Test func sectionsBecomePaths() throws {
    let e = try parseConfigEntries("general {\n  gaps_in = 10\n}\nbind = A, B, exec, x")
    #expect(e == [ConfigEntry(key: "general:gaps_in", value: "10", line: 2), ConfigEntry(key: "bind", value: "A, B, exec, x", line: 4)])
}

@Test func nestedSections() throws {
    #expect(try parseConfigEntries("a {\nb {\nc = 1\n}\n}")[0].key == "a:b:c")
}

@Test func variablesSubstitute() throws {
    #expect(try parseConfigEntries("$mod = CTRL ALT\nbind = $mod, Q, killactive")[0].value == "CTRL ALT, Q, killactive")
}

@Test func commentsIgnored() throws {
    #expect(try parseConfigEntries("# hi\ngaps = 1 # trailing").map(\.value) == ["1"])
}

@Test func unclosedSectionErrors() {
    #expect(throws: ConfigError(line: 1, message: "section 'general' is never closed")) {
        try parseConfigEntries("general {\n gaps_in = 1")
    }
}

@Test func strayBraceErrors() {
    #expect(throws: ConfigError(line: 1, message: "unexpected '}'")) { try parseConfigEntries("}") }
}

@Test func lineWithoutEqualsErrors() {
    #expect(throws: ConfigError(line: 1, message: "expected 'key = value'")) { try parseConfigEntries("nonsense") }
}

@Test func undefinedVariableErrors() {
    #expect(throws: ConfigError(line: 1, message: "undefined variable '$nope'")) {
        try parseConfigEntries("bind = $nope, Q, killactive")
    }
}

@Test func longestVariableNameWins() throws {
    #expect(try parseConfigEntries("$a = 1\n$ab = 2\nk = $ab $a")[0].value == "2 1")
}

@Test func variablesChainAndAreGlobalFromDefinition() throws {
    let e = try parseConfigEntries("$a = x\n$b = $a-y\nsec {\n$c = $b-z\n}\nk = $c")
    #expect(e == [ConfigEntry(key: "k", value: "x-y-z", line: 6)])
}

@Test func variableUsedBeforeDefinitionErrors() {
    #expect(throws: ConfigError(line: 1, message: "undefined variable '$late'")) {
        try parseConfigEntries("k = $late\n$late = 1")
    }
}

@Test func braceInsideAssignmentIsAValue() throws {
    #expect(try parseConfigEntries("s {\nk = a{b\n}")[0] == ConfigEntry(key: "s:k", value: "a{b", line: 2))
}
