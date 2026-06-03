import Foundation
@testable import GazeGesturesApp

enum HandGestureReplayFixtures {
    static func pinchClickRelease(startingAt timestamp: TimeInterval = 10) -> [HandLandmarkObservation] {
        [
            pinching(midpointX: 0.42, midpointY: 0.50, timestamp: timestamp),
            pinching(midpointX: 0.42, midpointY: 0.50, timestamp: timestamp + 0.10),
            open(midpointX: 0.42, midpointY: 0.50, timestamp: timestamp + 0.90),
            open(midpointX: 0.42, midpointY: 0.50, timestamp: timestamp + 1)
        ]
    }

    static func sustainedDrag(startingAt timestamp: TimeInterval = 20) -> [HandLandmarkObservation] {
        [
            pinching(midpointX: 0.42, midpointY: 0.50, timestamp: timestamp),
            pinching(midpointX: 0.42, midpointY: 0.50, timestamp: timestamp + 0.10),
            pinching(midpointX: 0.48, midpointY: 0.50, timestamp: timestamp + 0.25),
            pinching(midpointX: 0.54, midpointY: 0.50, timestamp: timestamp + 0.40),
            open(midpointX: 0.54, midpointY: 0.50, timestamp: timestamp + 0.55),
            open(midpointX: 0.54, midpointY: 0.50, timestamp: timestamp + 0.65)
        ]
    }

    static func openHandScroll(startingAt timestamp: TimeInterval = 30) -> [HandLandmarkObservation] {
        [
            open(midpointX: 0.40, midpointY: 0.50, timestamp: timestamp),
            open(midpointX: 0.40, midpointY: 0.50, timestamp: timestamp + 0.10),
            open(midpointX: 0.40, midpointY: 0.65, timestamp: timestamp + 0.20),
            open(midpointX: 0.40, midpointY: 0.65, timestamp: timestamp + 0.30)
        ]
    }

    private static func pinching(
        midpointX: Double,
        midpointY: Double,
        timestamp: TimeInterval
    ) -> HandLandmarkObservation {
        HandLandmarkObservation(
            thumbTip: HandLandmarkPoint(
                location: NormalizedPoint(x: midpointX - 0.02, y: midpointY),
                confidence: 0.90
            ),
            indexTip: HandLandmarkPoint(
                location: NormalizedPoint(x: midpointX + 0.02, y: midpointY),
                confidence: 0.92
            ),
            timestamp: timestamp
        )
    }

    private static func open(
        midpointX: Double,
        midpointY: Double,
        timestamp: TimeInterval
    ) -> HandLandmarkObservation {
        HandLandmarkObservation(
            thumbTip: HandLandmarkPoint(
                location: NormalizedPoint(x: midpointX - 0.075, y: midpointY),
                confidence: 0.90
            ),
            indexTip: HandLandmarkPoint(
                location: NormalizedPoint(x: midpointX + 0.075, y: midpointY),
                confidence: 0.92
            ),
            timestamp: timestamp
        )
    }
}
