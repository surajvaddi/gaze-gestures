import XCTest
@testable import GazeGesturesApp

final class HandModeTests: XCTestCase {
    func testHandModeActionEqualityCoversCoreActions() {
        XCTAssertEqual(
            HandModeAction.click(ScreenPoint(x: 10, y: 20)),
            .click(ScreenPoint(x: 10, y: 20))
        )
        XCTAssertEqual(
            HandModeAction.drag(.started(ScreenPoint(x: 10, y: 20))),
            .drag(.started(ScreenPoint(x: 10, y: 20)))
        )
        XCTAssertEqual(
            HandModeAction.scroll(HandScrollDelta(horizontal: 0, vertical: -4)),
            .scroll(HandScrollDelta(horizontal: 0, vertical: -4))
        )
        XCTAssertEqual(HandModeAction.freeze(true), .freeze(true))
        XCTAssertEqual(HandModeAction.cancel, .cancel)
    }

    func testHandModeActionsWithDifferentPayloadsAreNotEqual() {
        XCTAssertNotEqual(
            HandModeAction.click(ScreenPoint(x: 10, y: 20)),
            .click(ScreenPoint(x: 11, y: 20))
        )
        XCTAssertNotEqual(
            HandModeAction.drag(.started(ScreenPoint(x: 10, y: 20))),
            .drag(.ended(ScreenPoint(x: 10, y: 20)))
        )
        XCTAssertNotEqual(HandModeAction.freeze(true), .freeze(false))
    }

    func testHandScrollDeltaZeroDetection() {
        XCTAssertTrue(HandScrollDelta(horizontal: 0, vertical: 0).isZero)
        XCTAssertFalse(HandScrollDelta(horizontal: 1, vertical: 0).isZero)
        XCTAssertFalse(HandScrollDelta(horizontal: 0, vertical: -1).isZero)
    }

    func testHandModeActionStateTerminalStatus() {
        XCTAssertFalse(HandModeActionState.idle.isTerminal)
        XCTAssertFalse(
            HandModeActionState
                .preparing(.drag(.started(ScreenPoint(x: 10, y: 20))))
                .isTerminal
        )
        XCTAssertFalse(
            HandModeActionState
                .active(.drag(.moved(ScreenPoint(x: 10, y: 20))))
                .isTerminal
        )
        XCTAssertTrue(
            HandModeActionState
                .completed(.click(ScreenPoint(x: 10, y: 20)))
                .isTerminal
        )
        XCTAssertTrue(HandModeActionState.cancelled.isTerminal)
    }
}
