import XCTest
@testable import GazeGesturesApp

final class PinchCursorOverlayLayoutTests: XCTestCase {
    func testOverlayLayoutConvertsScreenPointToSwiftUITopLeftCoordinates() {
        let layout = PinchCursorOverlayLayout(
            screenBounds: ScreenBounds(
                origin: ScreenPoint(x: 0, y: 0),
                width: 100,
                height: 80
            )
        )

        XCTAssertEqual(
            layout.localPoint(for: ScreenPoint(x: 25, y: 30)),
            ScreenPoint(x: 25, y: 50)
        )
    }

    func testOverlayLayoutHandlesNonZeroScreenOrigin() {
        let layout = PinchCursorOverlayLayout(
            screenBounds: ScreenBounds(
                origin: ScreenPoint(x: 100, y: 200),
                width: 300,
                height: 400
            )
        )

        XCTAssertEqual(
            layout.localPoint(for: ScreenPoint(x: 130, y: 250)),
            ScreenPoint(x: 30, y: 350)
        )
    }
}
