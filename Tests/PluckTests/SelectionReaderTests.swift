import Testing
import Foundation
import CoreGraphics
@testable import Pluck

final class FakePasteboard: Pasteboard, @unchecked Sendable {
    private let lock = NSLock()
    private var _string: String?
    func readString() -> String? { lock.withLock { _string } }
    func write(_ string: String) { lock.withLock { _string = string } }
}

final class FakeAXSource: AXSelectionSource, @unchecked Sendable {
    var result: AXHit = .miss
    var textTarget = true
    func readSelection(at screenPoint: CGPoint) -> AXHit { result }
    func isTextTarget(at screenPoint: CGPoint) -> Bool { textTarget }
}

private func makeBlocklist(_ entries: [String]) -> Blocklist {
    let defaults = UserDefaults(suiteName: "pluck.test.\(UUID().uuidString)")!
    defaults.set(entries, forKey: "pluck.blocklist")
    return Blocklist(defaults: defaults, key: "pluck.blocklist")
}

struct SelectionReaderTests {
    @Test func axSelectionWritesClipboardAndReturnsText() async {
        let ax = FakeAXSource()
        ax.result = .selection("hello", bundleID: "com.apple.Safari")
        let pb = FakePasteboard()
        let reader = SelectionReader(ax: ax, pasteboard: pb,
                                     blocklist: makeBlocklist([]))
        let outcome = await reader.read(at: .zero)
        #expect(outcome?.text == "hello")
        #expect(pb.readString() == "hello")
    }

    @Test func axSelectionFromBlockedAppReturnsNilAndDoesNotWrite() async {
        let ax = FakeAXSource()
        ax.result = .selection("hello", bundleID: "com.figma.Desktop")
        let pb = FakePasteboard()
        let reader = SelectionReader(ax: ax, pasteboard: pb,
                                     blocklist: makeBlocklist(["com.figma.Desktop"]))
        let outcome = await reader.read(at: .zero)
        #expect(outcome == nil)
        #expect(pb.readString() == nil)
    }

    /// Regression: AX-reported "no selection" must be a silent no-op. The
    /// previous bug synthesized Cmd+C here, which made apps NSBeep.
    @Test func axNoSelectionIsSilentNoOp() async {
        let ax = FakeAXSource()
        ax.result = .noSelection(bundleID: "com.apple.Safari")
        let pb = FakePasteboard()
        let reader = SelectionReader(ax: ax, pasteboard: pb,
                                     blocklist: makeBlocklist([]))
        let outcome = await reader.read(at: .zero)
        #expect(outcome == nil)
        #expect(pb.readString() == nil)
    }

    // MARK: Copy on select

    private func reader(_ hit: AXHit, onText: Bool, _ pb: FakePasteboard) -> SelectionReader {
        let ax = FakeAXSource()
        ax.result = hit
        ax.textTarget = onText
        return SelectionReader(ax: ax, pasteboard: pb, blocklist: makeBlocklist([]))
    }

    @Test func gestureStartedOnTextYieldsSelection() async {
        let r = reader(.selection("new", bundleID: "com.apple.TextEdit"), onText: true, FakePasteboard())
        #expect(await r.selectionFromGesture(press: .zero, release: .zero) == "new")
    }

    /// Dragging a window, a file or a slider starts off text: an existing
    /// selection elsewhere must not be copied.
    @Test func gestureStartedOffTextYieldsNothing() async {
        let r = reader(.selection("stale", bundleID: "com.apple.TextEdit"), onText: false, FakePasteboard())
        #expect(await r.selectionFromGesture(press: .zero, release: .zero) == nil)
    }

    @Test func gestureWithoutSelectionYieldsNothing() async {
        let r = reader(.noSelection(bundleID: "com.apple.TextEdit"), onText: true, FakePasteboard())
        #expect(await r.selectionFromGesture(press: .zero, release: .zero) == nil)
    }

    @Test func gestureInBlockedAppYieldsNothing() async {
        let ax = FakeAXSource()
        ax.result = .selection("x", bundleID: "com.figma.Desktop")
        ax.textTarget = true
        let r = SelectionReader(ax: ax, pasteboard: FakePasteboard(),
                                blocklist: makeBlocklist(["com.figma.Desktop"]))
        #expect(await r.selectionFromGesture(press: .zero, release: .zero) == nil)
    }

    @Test func writeIfNewWritesChangedText() {
        let pb = FakePasteboard()
        pb.write("old")
        let r = reader(.miss, onText: true, pb)
        #expect(r.writeIfNew("new")?.text == "new")
        #expect(pb.readString() == "new")
    }

    @Test func writeIfNewSkipsTextAlreadyOnClipboard() {
        let pb = FakePasteboard()
        pb.write("same")
        let r = reader(.miss, onText: true, pb)
        #expect(r.writeIfNew("same") == nil)
    }

    // MARK: AX role classification

    @Test func textRolesAreText() {
        #expect(axRolesAreText(["AXTextArea", "AXScrollArea", "AXWindow"]))
        #expect(axRolesAreText(["AXTextField", "AXGroup", "AXWindow"]))
        #expect(axRolesAreText(["AXStaticText", "AXGroup", "AXWebArea", "AXScrollArea"]))
    }

    @Test func controlsAndChromeAreNotText() {
        #expect(!axRolesAreText(["AXWindow"]))
        #expect(!axRolesAreText(["AXButton", "AXToolbar", "AXWindow"]))
        #expect(!axRolesAreText(["AXSlider", "AXGroup", "AXWebArea"]))
        #expect(!axRolesAreText(["AXImage", "AXCell", "AXRow", "AXOutline"]))
        #expect(!axRolesAreText([]))
    }

    /// A window title is an AXStaticText right under AXWindow; dragging it
    /// moves the window.
    @Test func staticTextOutsideATextContainerIsNotText() {
        #expect(!axRolesAreText(["AXStaticText", "AXWindow"]))
        #expect(!axRolesAreText(["AXStaticText", "AXButton", "AXWebArea"]))
    }

    @Test func axMissIsSilentNoOp() async {
        let ax = FakeAXSource()
        ax.result = .miss
        let pb = FakePasteboard()
        let reader = SelectionReader(ax: ax, pasteboard: pb,
                                     blocklist: makeBlocklist([]))
        let outcome = await reader.read(at: .zero)
        #expect(outcome == nil)
        #expect(pb.readString() == nil)
    }
}
