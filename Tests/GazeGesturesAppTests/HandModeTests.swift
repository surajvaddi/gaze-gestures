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

    func testConservativeHandScrollConfigurationDefaultsAreExplicit() {
        let configuration = HandScrollConfiguration.conservativeDefault

        XCTAssertEqual(configuration.minimumMovement, 3)
        XCTAssertEqual(configuration.horizontalScale, 0.25)
        XCTAssertEqual(configuration.verticalScale, 0.25)
    }

    func testHandScrollIntentDetectorDoesNotScrollOnFirstPoint() {
        let detector = HandScrollIntentDetector()

        XCTAssertEqual(
            detector.process(point: ScreenPoint(x: 10, y: 20)),
            .none
        )
    }

    func testHandScrollIntentDetectorIgnoresMovementInsideDeadZone() {
        let detector = HandScrollIntentDetector(
            configuration: HandScrollConfiguration(
                minimumMovement: 4,
                horizontalScale: 1,
                verticalScale: 1
            )
        )

        _ = detector.process(point: ScreenPoint(x: 10, y: 20))

        XCTAssertEqual(
            detector.process(point: ScreenPoint(x: 13, y: 23)),
            .none
        )
    }

    func testHandScrollIntentDetectorScalesMovementIntoDelta() {
        let detector = HandScrollIntentDetector(
            configuration: HandScrollConfiguration(
                minimumMovement: 2,
                horizontalScale: 0.50,
                verticalScale: -0.25
            )
        )

        _ = detector.process(point: ScreenPoint(x: 10, y: 20))

        XCTAssertEqual(
            detector.process(point: ScreenPoint(x: 14, y: 12)),
            .scrolled(HandScrollDelta(horizontal: 2, vertical: 2))
        )
    }

    func testHandScrollIntentDetectorResetClearsReferencePoint() {
        let detector = HandScrollIntentDetector(
            configuration: HandScrollConfiguration(
                minimumMovement: 1,
                horizontalScale: 1,
                verticalScale: 1
            )
        )

        _ = detector.process(point: ScreenPoint(x: 10, y: 20))
        detector.reset()

        XCTAssertEqual(
            detector.process(point: ScreenPoint(x: 20, y: 30)),
            .none
        )
    }

    func testHandScrollIntentDetectorMissingPointClearsReferencePoint() {
        let detector = HandScrollIntentDetector(
            configuration: HandScrollConfiguration(
                minimumMovement: 1,
                horizontalScale: 1,
                verticalScale: 1
            )
        )

        _ = detector.process(point: ScreenPoint(x: 10, y: 20))
        XCTAssertEqual(detector.process(point: nil), .none)

        XCTAssertEqual(
            detector.process(point: ScreenPoint(x: 20, y: 30)),
            .none
        )
    }

    func testConservativePinchDragConfigurationDefaultsAreExplicit() {
        let configuration = PinchDragConfiguration.conservativeDefault

        XCTAssertEqual(configuration.holdDuration, 0.45)
        XCTAssertEqual(configuration.minimumMovement, 2)
    }

    func testPinchDragIntentTrackerDoesNotStartBeforeHoldDuration() {
        let tracker = PinchDragIntentTracker(
            configuration: PinchDragConfiguration(holdDuration: 0.50, minimumMovement: 1)
        )

        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .pinching, timestamp: 10),
                cursorPoint: ScreenPoint(x: 10, y: 20)
            ),
            .none
        )
        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .pinching, timestamp: 10.49),
                cursorPoint: ScreenPoint(x: 11, y: 20)
            ),
            .none
        )
    }

    func testPinchDragIntentTrackerStartsAfterHoldDuration() {
        let tracker = PinchDragIntentTracker(
            configuration: PinchDragConfiguration(holdDuration: 0.50, minimumMovement: 1)
        )

        _ = tracker.process(
            observation: pinchObservation(state: .pinching, timestamp: 10),
            cursorPoint: ScreenPoint(x: 10, y: 20)
        )

        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .pinching, timestamp: 10.50),
                cursorPoint: ScreenPoint(x: 12, y: 20)
            ),
            .started(ScreenPoint(x: 12, y: 20))
        )
    }

    func testPinchDragIntentTrackerMovesOnlyAfterMinimumMovement() {
        let tracker = PinchDragIntentTracker(
            configuration: PinchDragConfiguration(holdDuration: 0, minimumMovement: 3)
        )

        _ = tracker.process(
            observation: pinchObservation(state: .pinching, timestamp: 10),
            cursorPoint: ScreenPoint(x: 10, y: 20)
        )
        _ = tracker.process(
            observation: pinchObservation(state: .pinching, timestamp: 10.10),
            cursorPoint: ScreenPoint(x: 10, y: 20)
        )

        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .pinching, timestamp: 10.20),
                cursorPoint: ScreenPoint(x: 12, y: 20)
            ),
            .none
        )
        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .pinching, timestamp: 10.30),
                cursorPoint: ScreenPoint(x: 13, y: 20)
            ),
            .moved(ScreenPoint(x: 13, y: 20))
        )
    }

    func testPinchDragIntentTrackerEndsOnOpenAfterDragStarted() {
        let tracker = PinchDragIntentTracker(
            configuration: PinchDragConfiguration(holdDuration: 0, minimumMovement: 1)
        )

        _ = tracker.process(
            observation: pinchObservation(state: .pinching, timestamp: 10),
            cursorPoint: ScreenPoint(x: 10, y: 20)
        )
        _ = tracker.process(
            observation: pinchObservation(state: .pinching, timestamp: 10.10),
            cursorPoint: ScreenPoint(x: 12, y: 20)
        )

        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .open, timestamp: 10.20),
                cursorPoint: nil
            ),
            .ended(ScreenPoint(x: 12, y: 20))
        )
    }

    func testPinchDragIntentTrackerOpenBeforeDragDoesNotEmitEnd() {
        let tracker = PinchDragIntentTracker(
            configuration: PinchDragConfiguration(holdDuration: 1, minimumMovement: 1)
        )

        _ = tracker.process(
            observation: pinchObservation(state: .pinching, timestamp: 10),
            cursorPoint: ScreenPoint(x: 10, y: 20)
        )

        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .open, timestamp: 10.20),
                cursorPoint: nil
            ),
            .none
        )
    }

    func testPinchDragIntentTrackerCancelsOnUnknownOrMissingPoint() {
        let tracker = PinchDragIntentTracker()

        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .pinching, timestamp: 10),
                cursorPoint: nil
            ),
            .cancelled
        )
        XCTAssertEqual(
            tracker.process(
                observation: pinchObservation(state: .unknown, timestamp: 11),
                cursorPoint: nil
            ),
            .cancelled
        )
    }
}

private func pinchObservation(
    state: PinchState,
    timestamp: TimeInterval,
    confidence: Double = 0.90
) -> PinchObservation {
    PinchObservation(
        state: state,
        thumbTip: nil,
        indexTip: nil,
        midpoint: NormalizedPoint(x: 0.40, y: 0.50),
        normalizedDistance: nil,
        confidence: confidence,
        timestamp: timestamp
    )
}
