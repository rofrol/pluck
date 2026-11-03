import Testing
import CoreGraphics
@testable import Pluck

struct HUDGeometryTests {
    private let pill = CGSize(width: 92, height: 30)
    // AppKit main screen: 0,0 = bottom-left. Frame 1440x900.
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func panelOriginSitsNearTheRightEdge() {
        let origin = HUDGeometry.panelOrigin(pillSize: pill, screenFrame: screen)
        #expect(origin.x == screen.maxX - HUDGeometry.rightOffset - pill.width)
    }

    @Test func aPillWiderThanTheScreenStartsAtItsLeftEdge() {
        let wide = CGSize(width: 2000, height: 30)
        #expect(HUDGeometry.panelOrigin(pillSize: wide, screenFrame: screen).x == screen.minX)
    }

    @Test func panelOriginSitsAtFixedBottomOffset() {
        let origin = HUDGeometry.panelOrigin(pillSize: pill, screenFrame: screen)
        #expect(origin.y == screen.minY + HUDGeometry.bottomOffset)
    }

    @Test func panelOriginHonorsSecondaryScreen() {
        let secondary = CGRect(x: 1440, y: 200, width: 1024, height: 768)
        let origin = HUDGeometry.panelOrigin(pillSize: pill, screenFrame: secondary)
        #expect(origin.x == secondary.maxX - HUDGeometry.rightOffset - pill.width)
        #expect(origin.y == secondary.minY + HUDGeometry.bottomOffset)
    }

    @Test func panelOriginHandlesNonZeroScreenOrigin() {
        // Screen with non-zero origin (common for stacked multi-monitor).
        let offset = CGRect(x: -1920, y: 300, width: 1920, height: 1080)
        let origin = HUDGeometry.panelOrigin(pillSize: pill, screenFrame: offset)
        #expect(origin.x == offset.maxX - HUDGeometry.rightOffset - pill.width)
        #expect(origin.y == offset.minY + HUDGeometry.bottomOffset)
    }
}
