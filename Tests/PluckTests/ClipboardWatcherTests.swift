import AppKit
import Testing
@testable import Pluck

struct ClipboardWatcherTests {
    @Test func textCopyIsCountedInCharacters() {
        let count = ClipboardWatcher.copiedCharacterCount(
            types: [.string], readString: { "hi \u{1F44B}\u{1F3FD}" })
        #expect(count == 4)
    }

    @Test func nonTextCopyIsIgnored() {
        var read = false
        let count = ClipboardWatcher.copiedCharacterCount(
            types: [.png], readString: { read = true; return nil })
        #expect(count == nil)
        #expect(!read)
    }

    @Test func emptyTextIsIgnored() {
        #expect(ClipboardWatcher.copiedCharacterCount(types: [.string], readString: { "" }) == nil)
    }

    /// A password manager's concealed copy is never read, so no secret
    /// passes through Pluck.
    @Test func concealedCopyIsNeverRead() {
        var read = false
        let count = ClipboardWatcher.copiedCharacterCount(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            readString: { read = true; return "secret" })
        #expect(count == nil)
        #expect(!read)
    }

    @Test func transientCopyIsIgnored() {
        let count = ClipboardWatcher.copiedCharacterCount(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.TransientType")],
            readString: { "x" })
        #expect(count == nil)
    }
}
