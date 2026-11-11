public struct EditableBind: Equatable, Sendable, Identifiable {
    public var line: Int
    public var mods: String
    public var key: String
    public var dispatcher: String
    public var args: String

    public init(line: Int = -1, mods: String, key: String, dispatcher: String, args: String = "") {
        self.line = line
        self.mods = mods
        self.key = key
        self.dispatcher = dispatcher
        self.args = args
    }

    public var id: Int { line }

    var rendered: String {
        "bind = \(mods), \(key), \(dispatcher)" + (args.isEmpty ? "" : ", \(args)")
    }
}

public struct ConfigEditor: Equatable, Sendable {
    public private(set) var lines: [String]

    public init(text: String) {
        lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    public var text: String { lines.joined(separator: "\n") }

    public func value(_ key: String) -> String? {
        scan().assignments.last { $0.path == key }?.value
    }

    public mutating func set(_ key: String, _ value: String) {
        let scanned = scan()
        if let a = scanned.assignments.last(where: { $0.path == key }) {
            lines[a.line] = a.indent + a.key + " = " + value + a.tail
            return
        }
        var path = key.split(separator: ":").map(String.init)
        let name = path.removeLast()
        let sectionPath = path.joined(separator: ":")
        if path.isEmpty {
            let at = lines.firstIndex { line in
                let code = Self.code(line)
                return !code.isEmpty
            } ?? lines.count
            lines.insert("\(name) = \(value)", at: at)
        } else if let section = scanned.sections.first(where: { $0.path == sectionPath }) {
            let indent = scanned.assignments.last { $0.section == sectionPath }?.indent ?? section.indent + "    "
            lines.insert(indent + name + " = " + value, at: section.close)
        } else {
            if let last = lines.last, !last.isEmpty { lines.append("") }
            lines += ["\(sectionPath) {", "    \(name) = \(value)", "}"]
        }
    }

    public mutating func remove(_ key: String) {
        let doomed = Set(scan().assignments.filter { $0.path == key }.map(\.line))
        lines = lines.enumerated().filter { !doomed.contains($0.offset) }.map(\.element)
    }

    public var binds: [EditableBind] {
        scan().assignments.filter { $0.path == "bind" }.map { a in
            let parts = a.value.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false)
                .map { String($0).trimmed }
            func part(_ i: Int) -> String { i < parts.count ? parts[i] : "" }
            return EditableBind(line: a.line, mods: part(0), key: part(1), dispatcher: part(2), args: part(3))
        }
    }

    public mutating func setBind(_ bind: EditableBind) {
        guard let a = scan().assignments.first(where: { $0.line == bind.line && $0.path == "bind" }) else { return }
        lines[a.line] = a.indent + bind.rendered + a.tail
    }

    public mutating func addBind(_ bind: EditableBind) {
        let last = binds.last?.line
        let at = last.map { $0 + 1 } ?? lines.count
        lines.insert(bind.rendered, at: at)
    }

    public mutating func removeBind(at line: Int) {
        guard scan().assignments.contains(where: { $0.line == line && $0.path == "bind" }) else { return }
        lines.remove(at: line)
    }

    public var mod: String? { value("$mod") }

    public mutating func setMod(_ mods: String) {
        set("$mod", mods)
    }

    private struct Assignment {
        let line: Int
        let section: String
        let path: String
        let indent: String
        let key: String
        let value: String
        let tail: String
    }

    private struct Section {
        let path: String
        let indent: String
        let close: Int
    }

    private static func code(_ line: String) -> String {
        String(line.prefix { $0 != "#" }).trimmed
    }

    private func scan() -> (assignments: [Assignment], sections: [Section]) {
        var assignments: [Assignment] = []
        var sections: [Section] = []
        var open: [(name: String, indent: String)] = []
        for (index, line) in lines.enumerated() {
            let code = Self.code(line)
            let indent = String(line.prefix { $0.isWhitespace })
            if code == "}" {
                if let closing = open.popLast() {
                    sections.append(Section(path: (open.map(\.name) + [closing.name]).joined(separator: ":"),
                                            indent: closing.indent, close: index))
                }
            } else if code.hasSuffix("{"), !code.contains("=") {
                open.append((String(code.dropLast()).trimmed, indent))
            } else if let equals = code.firstIndex(of: "=") {
                let key = String(code[..<equals]).trimmed
                let value = String(code[code.index(after: equals)...]).trimmed
                let hash = line.firstIndex(of: "#")
                let beforeHash = hash.map { String(line[..<$0]) } ?? line
                let gap = String(beforeHash.reversed().prefix { $0.isWhitespace }.reversed())
                let tail = hash.map { gap + line[$0...] } ?? ""
                let section = open.map(\.name).joined(separator: ":")
                let path = key.hasPrefix("$") || section.isEmpty ? key : section + ":" + key
                assignments.append(Assignment(line: index, section: section, path: path, indent: indent,
                                              key: key, value: value, tail: tail))
            }
        }
        return (assignments, sections)
    }
}

public func formatColor(_ color: RGBA) -> String {
    let digits = "0123456789abcdef"
    func hex(_ v: Double) -> String {
        let n = Int((min(max(v, 0), 1) * 255).rounded())
        return String([digits[digits.index(digits.startIndex, offsetBy: n / 16)],
                       digits[digits.index(digits.startIndex, offsetBy: n % 16)]])
    }
    return "rgba(\(hex(color.r))\(hex(color.g))\(hex(color.b))\(hex(color.a)))"
}

public func formatGradient(_ gradient: Gradient) -> String {
    let colors = gradient.colors.map(formatColor).joined(separator: " ")
    guard gradient.colors.count > 1 else { return colors }
    return "\(colors) \(Int(gradient.angleDegrees.rounded()))deg"
}

public func formatInsets(_ insets: Insets, perSide: Bool) -> String {
    func number(_ v: Double) -> String { v.rounded() == v ? String(Int(v)) : String(v) }
    guard perSide else { return number(insets.top) }
    return [insets.top, insets.right, insets.bottom, insets.left].map(number).joined(separator: " ")
}

private extension String {
    var trimmed: String {
        String(drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }
}
