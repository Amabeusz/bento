public enum ClipPreview: Equatable, Sendable {
    case plain
    case link(host: String, path: String)
    case color(r: Int, g: Int, b: Int, a: Int)
    case json(String)
}

public func clipPreview(for entry: ClipEntry) -> ClipPreview {
    guard entry.kind == .text, !entry.secret else { return .plain }
    let text = trimmed(entry.text)
    if let link = link(text) { return link }
    if let color = color(text) { return color }
    if let json = prettyJSON(text) { return .json(json) }
    return .plain
}

public func previewFontSize(_ text: String) -> Double {
    let lines = text.split(whereSeparator: \.isNewline).count
    if lines > 1 || text.count > 400 { return 13 }
    if text.count > 120 { return 15 }
    return text.count > 40 ? 20 : 26
}

public func prettyJSON(_ text: String) -> String? {
    let chars = Array(trimmed(text))
    guard let first = chars.first, let last = chars.last,
          (first == "{" && last == "}") || (first == "[" && last == "]")
    else { return nil }
    var out = ""
    var stack: [Character] = []
    var inString = false
    var escaped = false
    var bare = ""
    var i = 0
    func bareIsValid() -> Bool {
        defer { bare = "" }
        guard !bare.isEmpty else { return true }
        if ["true", "false", "null"].contains(bare) { return true }
        guard let head = bare.first, head == "-" || head.isNumber else { return false }
        return Double(bare) != nil
    }
    func newline() { out += "\n" + String(repeating: "  ", count: stack.count) }
    func nextSolid() -> Int? { chars[(i + 1)...].firstIndex { !$0.isWhitespace } }
    while i < chars.count {
        let c = chars[i]
        if inString {
            out.append(c)
            if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
        } else {
            if !c.isWhitespace, !c.isLetter, !c.isNumber, !"-+.".contains(c), !bareIsValid() { return nil }
            switch c {
            case "\"":
                inString = true
                out.append(c)
            case "{", "[":
                let close: Character = c == "{" ? "}" : "]"
                let next = nextSolid().map { chars[$0] }
                guard c == "[" || next == "\"" || next == "}" else { return nil }
                if next == close {
                    out += String([c, close])
                    i = nextSolid()!
                } else {
                    out.append(c)
                    stack.append(close)
                    newline()
                }
            case "}", "]":
                guard stack.popLast() == c else { return nil }
                newline()
                out.append(c)
            case ",":
                guard !stack.isEmpty else { return nil }
                out.append(c)
                newline()
            case ":":
                out += ": "
            case _ where c.isWhitespace:
                guard !bare.isEmpty else { break }
                guard bareIsValid(), let next = nextSolid().map({ chars[$0] }), ",]}".contains(next) else { return nil }
            default:
                bare.append(c)
                out.append(c)
            }
            if stack.isEmpty, nextSolid() != nil { return nil }
        }
        i += 1
    }
    return inString || !stack.isEmpty ? nil : out
}

private func trimmed(_ text: String) -> String {
    String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
}

private func link(_ text: String) -> ClipPreview? {
    guard !text.contains(where: \.isWhitespace) else { return nil }
    guard let scheme = ["https://", "http://"].first(where: text.hasPrefix) else { return nil }
    let rest = text.dropFirst(scheme.count)
    let hostEnd = rest.firstIndex { "/?#".contains($0) } ?? rest.endIndex
    let host = String(rest[..<hostEnd])
    return host.isEmpty ? nil : .link(host: host, path: String(rest[hostEnd...]))
}

private func color(_ text: String) -> ClipPreview? {
    if text.hasPrefix("#") {
        var digits = Array(text.dropFirst())
        guard [3, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        if digits.count == 3 { digits = digits.flatMap { [$0, $0] } }
        let bytes = stride(from: 0, to: digits.count, by: 2).map { Int(String(digits[$0...$0 + 1]), radix: 16)! }
        return .color(r: bytes[0], g: bytes[1], b: bytes[2], a: bytes.count == 4 ? bytes[3] : 255)
    }
    let lower = text.lowercased()
    guard let open = lower.firstIndex(of: "("), lower.hasSuffix(")") else { return nil }
    let name = lower[..<open]
    let parts = lower[lower.index(after: open)..<lower.index(before: lower.endIndex)]
        .split(separator: ",").map { trimmed(String($0)) }
    guard (name == "rgb" && parts.count == 3) || (name == "rgba" && parts.count == 4) else { return nil }
    let rgb = parts.prefix(3).compactMap { Int($0) }
    guard rgb.count == 3, rgb.allSatisfy((0...255).contains) else { return nil }
    var alpha = 255
    if parts.count == 4 {
        guard let a = Double(parts[3]), (0...1).contains(a) else { return nil }
        alpha = Int((a * 255).rounded())
    }
    return .color(r: rgb[0], g: rgb[1], b: rgb[2], a: alpha)
}
