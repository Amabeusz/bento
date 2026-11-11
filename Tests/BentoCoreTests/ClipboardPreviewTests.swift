import Testing
@testable import BentoCore

private func text(_ s: String, secret: Bool = false) -> ClipEntry {
    ClipEntry(key: s, text: s, at: 0, secret: secret)
}

@Suite struct ClipboardPreviewTests {
    @Test func fontSizeShrinksWithLength() {
        #expect(previewFontSize("git push origin main") == 26)
        #expect(previewFontSize(String(repeating: "a", count: 40)) == 26)
        #expect(previewFontSize(String(repeating: "a", count: 41)) == 20)
        #expect(previewFontSize(String(repeating: "a", count: 120)) == 20)
        #expect(previewFontSize(String(repeating: "a", count: 121)) == 15)
        #expect(previewFontSize(String(repeating: "a", count: 400)) == 15)
        #expect(previewFontSize(String(repeating: "a", count: 401)) == 13)
        #expect(previewFontSize("short\nsecond line") == 13)
        #expect(previewFontSize(String(repeating: "line\n", count: 12)) == 13)
    }

    @Test func recognizesLinks() {
        #expect(clipPreview(for: text("https://jira.example.com/jira/browse/ABC-123"))
            == .link(host: "jira.example.com", path: "/jira/browse/ABC-123"))
        #expect(clipPreview(for: text("  http://example.com\n")) == .link(host: "example.com", path: ""))
        #expect(clipPreview(for: text("https://a.pl?q=1")) == .link(host: "a.pl", path: "?q=1"))
        #expect(clipPreview(for: text("see https://a.pl now")) == .plain)
        #expect(clipPreview(for: text("https://a.pl and more")) == .plain)
        #expect(clipPreview(for: text("https://")) == .plain)
    }

    @Test func recognizesColors() {
        #expect(clipPreview(for: text("#378ADD")) == .color(r: 0x37, g: 0x8A, b: 0xDD, a: 255))
        #expect(clipPreview(for: text("#fff")) == .color(r: 255, g: 255, b: 255, a: 255))
        #expect(clipPreview(for: text("#378ADD80")) == .color(r: 0x37, g: 0x8A, b: 0xDD, a: 0x80))
        #expect(clipPreview(for: text("rgb(55, 138, 221)")) == .color(r: 55, g: 138, b: 221, a: 255))
        #expect(clipPreview(for: text("rgba(55,138,221,0.5)")) == .color(r: 55, g: 138, b: 221, a: 128))
        #expect(clipPreview(for: text("#12345")) == .plain)
        #expect(clipPreview(for: text("#GGG")) == .plain)
        #expect(clipPreview(for: text("rgb(300, 0, 0)")) == .plain)
    }

    @Test func prettyPrintsJson() {
        #expect(clipPreview(for: text(#"{"a":1,"b":[1,2]}"#)) == .json("""
        {
          "a": 1,
          "b": [
            1,
            2
          ]
        }
        """))
        #expect(prettyJSON(#"["x, {y}", "z\"]"]"#) == """
        [
          "x, {y}",
          "z\\"]"
        ]
        """)
        #expect(prettyJSON("{}") == "{}")
        #expect(clipPreview(for: text(#"{"a":1"#)) == .plain)
        #expect(clipPreview(for: text("{hello")) == .plain)
        #expect(clipPreview(for: text("[TODO list items]")) == .plain)
        #expect(clipPreview(for: text("[1 2]")) == .plain)
        #expect(clipPreview(for: text("[nan]")) == .plain)
        #expect(prettyJSON("[true, null, -1.5e3]") == "[\n  true,\n  null,\n  -1.5e3\n]")
        #expect(clipPreview(for: text(#"{"a":"unterminated}"#)) == .plain)
    }

    @Test func secretStaysPlain() {
        #expect(clipPreview(for: text("https://jira.example.com/x", secret: true)) == .plain)
        #expect(clipPreview(for: text("#378ADD", secret: true)) == .plain)
        #expect(clipPreview(for: text(#"{"a":1}"#, secret: true)) == .plain)
    }
}
