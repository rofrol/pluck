import AppKit
import Testing
@testable import Pluck

struct ClipboardWatcherTests {
    @Test func textCopyIsReturned() {
        let count = ClipboardWatcher.copiedText(
            types: [.string], readString: { "hi \u{1F44B}\u{1F3FD}" })
        #expect(count == "hi \u{1F44B}\u{1F3FD}")
    }

    @Test func nonTextCopyIsIgnored() {
        var read = false
        let count = ClipboardWatcher.copiedText(
            types: [.png], readString: { read = true; return nil })
        #expect(count == nil)
        #expect(!read)
    }

    @Test func emptyTextIsIgnored() {
        #expect(ClipboardWatcher.copiedText(types: [.string], readString: { "" }) == nil)
    }

    /// A password manager's concealed copy is never read, so no secret
    /// passes through Pluck.
    @Test func concealedCopyIsNeverRead() {
        var read = false
        let count = ClipboardWatcher.copiedText(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            readString: { read = true; return "secret" })
        #expect(count == nil)
        #expect(!read)
    }

    @Test func transientCopyIsIgnored() {
        let count = ClipboardWatcher.copiedText(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.TransientType")],
            readString: { "x" })
        #expect(count == nil)
    }
}
