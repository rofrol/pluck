import AppKit

struct SelectionOutcome: Equatable, Sendable {
    var text: String
}

/// Reads the selected text under a screen point via AX and writes it to the
/// clipboard. AX-only by design: any AX outcome short of "here is a non-empty
/// selection" is a silent no-op. Previously we fell back to a synthesized
/// Cmd+C when AX reported no selection, which made every click on a non-text
/// element (Finder desktop, buttons, icons, most of macOS) emit NSBeep.
final class SelectionReader: @unchecked Sendable {
    private let ax: AXSelectionSource
    private let pasteboard: Pasteboard
    private let blocklist: Blocklist

    init(
        ax: AXSelectionSource = SystemAXSelectionSource(),
        pasteboard: Pasteboard = SystemPasteboard(),
        blocklist: Blocklist
    ) {
        self.ax = ax
        self.pasteboard = pasteboard
        self.blocklist = blocklist
    }

    func read(at screenPoint: CGPoint) async -> SelectionOutcome? {
        guard let text = await selectedText(at: screenPoint) else { return nil }
        pasteboard.write(text)
        return SelectionOutcome(text: text)
    }

    /// The current non-empty selection, or nil when there is none or the
    /// owning app is blocklisted. Does not touch the clipboard.
    func selectedText(at screenPoint: CGPoint) async -> String? {
        // `AXUIElementCopyElementAtPosition` is synchronous and can block
        // for seconds on an unresponsive target app; run it off the main
        // run loop so a slow AX call never starves the CGEventTap.
        let ax = self.ax
        let hit = await Task.detached(priority: .userInitiated) {
            ax.readSelection(at: screenPoint)
        }.value

        guard case let .selection(text, bundleID) = hit else { return nil }
        if let bundleID, blocklist.contains(bundleID) { return nil }
        return text
    }

    /// Copy-on-select, step 1: the text a selection gesture produced, or nil.
    /// The gesture counts only if it started on text (`pressPoint`), so a
    /// drag of a window, a file or a slider, or a double click on a button,
    /// never copies a selection that happens to exist elsewhere. Does not
    /// touch the clipboard.
    func selectionFromGesture(press pressPoint: CGPoint,
                              release releasePoint: CGPoint) async -> String? {
        let ax = self.ax
        let onText = await Task.detached(priority: .userInitiated) {
            ax.isTextTarget(at: pressPoint)
        }.value
        guard onText else { return nil }
        return await selectedText(at: releasePoint)
    }

    /// Copy-on-select, step 2: writes `text` unless it is already on the
    /// clipboard. Returns whether the clipboard changed.
    func writeIfNew(_ text: String) -> SelectionOutcome? {
        if pasteboard.readString() == text { return nil }
        pasteboard.write(text)
        return SelectionOutcome(text: text)
    }
}
