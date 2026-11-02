public struct ConfigEntry: Equatable, Sendable {
    public let key: String
    public let value: String
    public let line: Int

    public init(key: String, value: String, line: Int) {
        self.key = key
        self.value = value
        self.line = line
    }
}

public struct ConfigError: Error, Equatable, Sendable {
    public let line: Int
    public let message: String

    public init(line: Int, message: String) {
        self.line = line
        self.message = message
    }
}

public func parseConfigEntries(_ text: String) throws(ConfigError) -> [ConfigEntry] {
    var entries: [ConfigEntry] = []
    var sections: [(name: String, line: Int)] = []
    var variables: [String: String] = [:]

    for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let lineNumber = index + 1
        let line = rawLine.prefix { $0 != "#" }.trimmingSpaces()
        if line.isEmpty { continue }

        if line == "}" {
            guard sections.popLast() != nil else { throw ConfigError(line: lineNumber, message: "unexpected '}'") }
        } else if line.hasSuffix("{"), !line.contains("=") {
            let name = line.dropLast().trimmingSpaces()
            guard !name.isEmpty else { throw ConfigError(line: lineNumber, message: "expected section name") }
            sections.append((name, lineNumber))
        } else if let equals = line.firstIndex(of: "=") {
            let key = line[..<equals].trimmingSpaces()
            if key.isEmpty { throw ConfigError(line: lineNumber, message: "expected 'key = value'") }
            let value = try substituteVariables(in: line[line.index(after: equals)...].trimmingSpaces(), variables: variables, line: lineNumber)
            if key.hasPrefix("$") {
                variables[key] = value
            } else {
                entries.append(ConfigEntry(key: (sections.map(\.name) + [key]).joined(separator: ":"), value: value, line: lineNumber))
            }
        } else {
            throw ConfigError(line: lineNumber, message: "expected 'key = value'")
        }
    }

    if let open = sections.last {
        throw ConfigError(line: open.line, message: "section '\(open.name)' is never closed")
    }
    return entries
}

private func substituteVariables(in value: String, variables: [String: String], line: Int) throws(ConfigError) -> String {
    let namesLongestFirst = variables.keys.sorted { $0.count > $1.count }
    var result = ""
    var rest = Substring(value)
    while let dollar = rest.firstIndex(of: "$") {
        result += rest[..<dollar]
        rest = rest[dollar...]
        guard let name = namesLongestFirst.first(where: { rest.hasPrefix($0) }) else {
            let identifier = rest.dropFirst().prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if identifier.isEmpty {
                result += "$"
                rest = rest.dropFirst()
                continue
            }
            throw ConfigError(line: line, message: "undefined variable '$\(identifier)'")
        }
        result += variables[name] ?? ""
        rest = rest.dropFirst(name.count)
    }
    return result + rest
}

private extension Substring {
    func trimmingSpaces() -> String {
        var slice = self
        while slice.first?.isWhitespace == true { slice.removeFirst() }
        while slice.last?.isWhitespace == true { slice.removeLast() }
        return String(slice)
    }
}
