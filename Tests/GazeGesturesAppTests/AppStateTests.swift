import XCTest
@testable import GazeGesturesApp

final class AppStateTests: XCTestCase {
    func testAppStateStartsWithHiddenVirtualCursor() {
        let appState = AppState()

        XCTAssertEqual(appState.virtualCursorState, .hidden)
    }

    func testVirtualCursorStateCanRepresentVisiblePoint() {
        let point = ScreenPoint(x: 42, y: 84)

        XCTAssertEqual(VirtualCursorState.visible(point), .visible(point))
        XCTAssertNotEqual(VirtualCursorState.visible(point), .hidden)
    }
}
