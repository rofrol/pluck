import Testing
@testable import Pluck

struct CopiedPillTests {
    @Test func labelNamesTheCount() {
        #expect(CopiedPill.label(for: String(repeating: "a", count: 32)) == "Copied 32 chars")
    }

    @Test func labelUsesTheSingularForOne() {
        #expect(CopiedPill.label(for: "a") == "Copied 1 char")
    }

    /// The count is of what a person sees: an emoji with a skin-tone
    /// modifier is one character, though it is two Unicode scalars.
    @Test func countIsOfGraphemeClusters() {
        let text = "hi \u{1F44B}\u{1F3FD}"
        #expect(text.unicodeScalars.count == 5)
        #expect(CopiedPill.label(for: text) == "Copied 4 chars")
    }

    @Test func shortTextIsShownWhole() {
        #expect(CopiedPill.preview(of: "hello world") == "hello world")
    }

    @Test func longTextIsCutWithAnEllipsis() {
        let text = String(repeating: "abcd ", count: 20)
        let preview = CopiedPill.preview(of: text)
        #expect(preview.hasSuffix("…"))
        #expect(preview.count <= CopiedPill.previewLength + 1)
    }

    @Test func lineBreaksAndRunsOfSpacesBecomeOneSpace() {
        #expect(CopiedPill.preview(of: "  one\n\ntwo\t  three  ") == "one two three")
    }
}
