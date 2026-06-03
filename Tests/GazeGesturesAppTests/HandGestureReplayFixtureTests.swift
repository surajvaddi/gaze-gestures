import XCTest
@testable import GazeGesturesApp

final class HandGestureReplayFixtureTests: XCTestCase {
    func testPinchClickReleaseFixtureReplaysPinchThenOpen() {
        let states = classifiedStates(
            HandGestureReplayFixtures.pinchClickRelease(startingAt: 40)
        )

        XCTAssertEqual(states, [.pinching, .pinching, .open, .open])
    }

    func testSustainedDragFixtureMovesWhilePinchingThenOpens() {
        let observations = HandGestureReplayFixtures.sustainedDrag(startingAt: 50)
        let states = classifiedStates(observations)

        XCTAssertEqual(states, [.pinching, .pinching, .pinching, .pinching, .open, .open])
        XCTAssertEqual(observations[0].timestamp, 50)
        XCTAssertEqual(observations[3].timestamp, 50.40)
    }

    func testOpenHandScrollFixtureMovesOpenHandVertically() {
        let observations = HandGestureReplayFixtures.openHandScroll(startingAt: 60)
        let classifiedObservations = observations.map(PinchDistanceClassifier().classify)

        XCTAssertEqual(classifiedObservations.map(\.state), [.open, .open, .open, .open])
        XCTAssertEqual(classifiedObservations[0].midpoint?.y, 0.50)
        XCTAssertEqual(classifiedObservations[3].midpoint?.y, 0.65)
    }

    private func classifiedStates(_ observations: [HandLandmarkObservation]) -> [PinchState] {
        let classifier = PinchDistanceClassifier()

        return observations
            .map(classifier.classify)
            .map(\.state)
    }
}
