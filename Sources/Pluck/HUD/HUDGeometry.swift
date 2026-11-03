import CoreGraphics

/// The HUD lives at the bottom right of the screen containing the cursor
/// (the user, 2026-11-03: nearer the right edge). Pure function so it's
/// trivial to unit-test.
enum HUDGeometry {
    /// Distance from the bottom of the visible frame to the pill.
    static let bottomOffset: CGFloat = 120
    /// Distance from the right edge of the visible frame to the pill.
    static let rightOffset: CGFloat = 24

    /// Origin (bottom-left in AppKit coordinates) for a pill of `pillSize`
    /// placed `rightOffset` points in from the right edge of the given
    /// screen frame (but never past its left edge), offset `bottomOffset`
    /// points up from the bottom edge.
    static func panelOrigin(pillSize: CGSize, screenFrame: CGRect) -> CGPoint {
        let x = max(screenFrame.minX, screenFrame.maxX - rightOffset - pillSize.width)
        let y = screenFrame.minY + bottomOffset
        return CGPoint(x: x, y: y)
    }
}
