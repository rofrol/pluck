import Foundation
import CoreGraphics

/// Pure state machine for Pluck's gestures. No timers, no OS calls.
/// The engine feeds it events and consumes the returned `Action`s.
///
/// Two gestures:
/// - Hold: press on a selection, keep still for `holdDelay`, release.
/// - Select (when `copyOnSelect` is on): finish a selection, either by
///   releasing a drag that moved beyond `dragSlop` or by releasing a
///   double/triple click. The reader then checks that the gesture started
///   on text, so a drag that moved a window, a file or a slider copies
///   nothing.
struct GestureStateMachine: Sendable {
    enum SelectionKind: Equatable, Sendable {
        case drag
        /// A double or triple click, which selects a word or line.
        case multiClick
    }

    enum Action: Equatable, Sendable {
        case scheduleHoldTimer(delay: TimeInterval)
        case cancelHoldTimer
        case fireCopy(at: CGPoint)
        case fireSelectionCopy(press: CGPoint, release: CGPoint, kind: SelectionKind)
    }

    var holdDelay: TimeInterval = 0.15

    /// Drag events within this distance of the press point do NOT cancel
    /// the hold timer. Hand tremor and trackpad jitter commonly emit 1–3 pt
    /// drags during a stationary hold.
    var dragSlop: CGFloat = 4.0

    var copyOnSelect: Bool = true

    /// Anchor of an armed hold; nil once the hold is cancelled by a drag.
    private(set) var pressPoint: CGPoint?

    /// Where the current press started; nil when no button is down.
    private var pressOrigin: CGPoint?
    private var dragged = false
    private var multiClick = false

    mutating func onMouseDown(at point: CGPoint, clickCount: Int = 1) -> Action {
        pressPoint = point
        pressOrigin = point
        dragged = false
        multiClick = clickCount >= 2
        return .scheduleHoldTimer(delay: holdDelay)
    }

    /// A hold that already fired does not suppress the select copy: the
    /// reader skips text that is already on the clipboard, and a hold that
    /// read nothing (the app selects the word only on mouse-up) must not
    /// cost the double-click its copy.
    mutating func onMouseUp(at point: CGPoint? = nil) -> Action? {
        guard let origin = pressOrigin else { return nil }
        let wasDragged = dragged
        let wasMultiClick = multiClick
        clearPress()

        if copyOnSelect, let point, wasDragged || wasMultiClick {
            return .fireSelectionCopy(press: origin, release: point,
                                      kind: wasDragged ? .drag : .multiClick)
        }
        return .cancelHoldTimer
    }

    mutating func onMouseDragged(to point: CGPoint) -> Action? {
        guard let anchor = pressPoint else { return nil }
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        if dx * dx + dy * dy <= dragSlop * dragSlop {
            return nil
        }
        pressPoint = nil
        dragged = true
        return .cancelHoldTimer
    }

    mutating func onHoldTimerFired() -> Action? {
        guard let point = pressPoint else { return nil }
        return .fireCopy(at: point)
    }

    /// Clear all in-flight press state. Call when the event tap is
    /// disabled and re-enabled to avoid leaking a stale press.
    mutating func reset() {
        clearPress()
    }

    private mutating func clearPress() {
        pressPoint = nil
        pressOrigin = nil
        dragged = false
        multiClick = false
    }
}
