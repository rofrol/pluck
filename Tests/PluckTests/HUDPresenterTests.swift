import AppKit
import Testing
@testable import Pluck

@MainActor
struct HUDPresenterTests {
    /// Regression (crash of 2026-11-03, "Thread stack size exceeded due to
    /// excessive recursion" in Auto Layout): the second pill with a label of
    /// another length sent the hosting controller's own resizing and the
    /// manual setFrame into a layout loop. The panel must take each label's
    /// size instead.
    @Test func pillsOfDifferentLengthsResizeThePanel() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let hud = HUDPresenter()
        hud.show(near: .zero, text: "a")
        hud.panel?.displayIfNeeded()
        let short = try #require(hud.panel).frame.width
        hud.show(near: .zero, text: String(repeating: "wide text ", count: 6))
        hud.panel?.displayIfNeeded()
        let long = try #require(hud.panel).frame.width
        #expect(long > short)
        hud.show(near: .zero, text: "a")
        hud.panel?.displayIfNeeded()
        #expect(try #require(hud.panel).frame.width == short)
    }
}
