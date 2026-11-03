import SwiftUI

/// The "Copied 32 chars: first words of the text…" HUD — a static, dark
/// Liquid Glass capsule at the bottom right of the screen (the user,
/// 2026-11-03: larger text, a more visible pill, nearer the right edge,
/// with a preview). Panel alpha fades it in and out (see `HUDPresenter`).
struct CopiedPill: View {
    var text: String

    /// Longest preview, in characters, before the ellipsis.
    static let previewLength = 40

    /// "Copied 32 chars:" — characters as a person counts them (grapheme
    /// clusters), so an emoji with a skin-tone modifier counts as one.
    /// Pure, so it is unit-tested apart from SwiftUI.
    static func label(for text: String) -> String {
        let count = text.count
        return "Copied \(count.formatted()) \(count == 1 ? "char" : "chars"):"
    }

    /// The text on one line (runs of whitespace and line breaks become one
    /// space), cut to `previewLength` characters with an ellipsis. Pure.
    static func preview(of text: String) -> String {
        let oneLine = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard oneLine.count > previewLength else { return oneLine }
        return oneLine.prefix(previewLength)
            .trimmingCharacters(in: .whitespaces) + "…"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
            Text(Self.label(for: text))
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
            Text(Self.preview(of: text))
                .font(.system(size: 17))
                .opacity(0.85)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.black.opacity(0.6)), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .fixedSize()
    }
}

#Preview {
    CopiedPill(text: "Select text in any app, press down on the selection, keep the mouse still")
        .padding(40)
        .background(Color.white)
}
