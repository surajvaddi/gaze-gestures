import XCTest
@testable import GazeGesturesApp

final class PinchCursorTests: XCTestCase {
    func testNormalizedPointUnitBounds() {
        XCTAssertTrue(NormalizedPoint(x: 0, y: 0).isWithinUnitBounds)
        XCTAssertTrue(NormalizedPoint(x: 1, y: 1).isWithinUnitBounds)
        XCTAssertTrue(NormalizedPoint(x: 0.5, y: 0.25).isWithinUnitBounds)

        XCTAssertFalse(NormalizedPoint(x: -0.01, y: 0.5).isWithinUnitBounds)
        XCTAssertFalse(NormalizedPoint(x: 0.5, y: 1.01).isWithinUnitBounds)
    }

    func testHandLandmarkObservationRepresentsMissingRequiredLandmarks() {
        let complete = HandLandmarkObservation(
            thumbTip: HandLandmarkPoint(location: NormalizedPoint(x: 0.4, y: 0.5), confidence: 0.9),
            indexTip: HandLandmarkPoint(location: NormalizedPoint(x: 0.45, y: 0.5), confidence: 0.91),
            timestamp: 1
        )
        let missingThumb = HandLandmarkObservation(
            thumbTip: nil,
            indexTip: HandLandmarkPoint(location: NormalizedPoint(x: 0.45, y: 0.5), confidence: 0.91),
            timestamp: 1
        )
        let missingIndex = HandLandmarkObservation(
            thumbTip: HandLandmarkPoint(location: NormalizedPoint(x: 0.4, y: 0.5), confidence: 0.9),
            indexTip: nil,
            timestamp: 1
        )

        XCTAssertTrue(complete.hasRequiredPinchLandmarks)
        XCTAssertFalse(missingThumb.hasRequiredPinchLandmarks)
        XCTAssertFalse(missingIndex.hasRequiredPinchLandmarks)
    }

    func testPinchStateEquality() {
        XCTAssertEqual(PinchState.unknown, .unknown)
        XCTAssertEqual(PinchState.open, .open)
        XCTAssertEqual(PinchState.pinching, .pinching)
        XCTAssertNotEqual(PinchState.open, .pinching)
    }

    func testPinchObservationEquality() {
        let thumb = HandLandmarkPoint(location: NormalizedPoint(x: 0.4, y: 0.5), confidence: 0.9)
        let index = HandLandmarkPoint(location: NormalizedPoint(x: 0.45, y: 0.5), confidence: 0.91)
        let observation = PinchObservation(
            state: .pinching,
            thumbTip: thumb,
            indexTip: index,
            midpoint: NormalizedPoint(x: 0.425, y: 0.5),
            normalizedDistance: 0.05,
            confidence: 0.9,
            timestamp: 2
        )

        XCTAssertEqual(
            observation,
            PinchObservation(
                state: .pinching,
                thumbTip: thumb,
                indexTip: index,
                midpoint: NormalizedPoint(x: 0.425, y: 0.5),
                normalizedDistance: 0.05,
                confidence: 0.9,
                timestamp: 2
            )
        )
        XCTAssertNotEqual(
            observation,
            PinchObservation(
                state: .open,
                thumbTip: thumb,
                indexTip: index,
                midpoint: NormalizedPoint(x: 0.425, y: 0.5),
                normalizedDistance: 0.05,
                confidence: 0.9,
                timestamp: 2
            )
        )
    }

    func testConservativePinchClassificationDefaultsAreExplicit() {
        let configuration = PinchClassificationConfiguration.conservativeDefault

        XCTAssertEqual(configuration.pinchingDistanceThreshold, 0.055)
        XCTAssertEqual(configuration.openDistanceThreshold, 0.095)
        XCTAssertEqual(configuration.minimumLandmarkConfidence, 0.65)
    }

    func testConservativePinchStabilityDefaultsAreExplicit() {
        let configuration = PinchStabilityConfiguration.conservativeDefault

        XCTAssertEqual(configuration.requiredPinchingObservations, 3)
        XCTAssertEqual(configuration.requiredOpenObservations, 3)
    }

    func testCustomPinchClassificationConfigurationEquality() {
        let configuration = PinchClassificationConfiguration(
            pinchingDistanceThreshold: 0.05,
            openDistanceThreshold: 0.10,
            minimumLandmarkConfidence: 0.70
        )

        XCTAssertEqual(
            configuration,
            PinchClassificationConfiguration(
                pinchingDistanceThreshold: 0.05,
                openDistanceThreshold: 0.10,
                minimumLandmarkConfidence: 0.70
            )
        )
    }

    func testPinchCursorPointEquality() {
        let point = PinchCursorPoint(
            normalizedPoint: NormalizedPoint(x: 0.5, y: 0.25),
            confidence: 0.88,
            timestamp: 3
        )

        XCTAssertEqual(
            point,
            PinchCursorPoint(
                normalizedPoint: NormalizedPoint(x: 0.5, y: 0.25),
                confidence: 0.88,
                timestamp: 3
            )
        )
        XCTAssertNotEqual(
            point,
            PinchCursorPoint(
                normalizedPoint: NormalizedPoint(x: 0.5, y: 0.25),
                confidence: 0.87,
                timestamp: 3
            )
        )
    }

    func testPinchDistanceClassifierClassifiesCloseLandmarksAsPinching() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let observation = classifier.classify(
            landmarkObservation(
                thumb: NormalizedPoint(x: 0.40, y: 0.50),
                index: NormalizedPoint(x: 0.44, y: 0.50)
            )
        )

        XCTAssertEqual(observation.state, .pinching)
        XCTAssertEqual(observation.midpoint?.x ?? -1, 0.42, accuracy: 0.0001)
        XCTAssertEqual(observation.midpoint?.y ?? -1, 0.50, accuracy: 0.0001)
        XCTAssertEqual(observation.normalizedDistance ?? -1, 0.04, accuracy: 0.0001)
        XCTAssertEqual(observation.confidence, 0.90)
    }

    func testPinchDistanceClassifierClassifiesFarLandmarksAsOpen() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let observation = classifier.classify(
            landmarkObservation(
                thumb: NormalizedPoint(x: 0.30, y: 0.50),
                index: NormalizedPoint(x: 0.45, y: 0.50)
            )
        )

        XCTAssertEqual(observation.state, .open)
        XCTAssertEqual(observation.midpoint, NormalizedPoint(x: 0.375, y: 0.50))
        XCTAssertEqual(observation.normalizedDistance ?? -1, 0.15, accuracy: 0.0001)
    }

    func testPinchDistanceClassifierClassifiesThresholdGapAsUnknown() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let observation = classifier.classify(
            landmarkObservation(
                thumb: NormalizedPoint(x: 0.40, y: 0.50),
                index: NormalizedPoint(x: 0.47, y: 0.50)
            )
        )

        XCTAssertEqual(observation.state, .unknown)
        XCTAssertEqual(observation.normalizedDistance ?? -1, 0.07, accuracy: 0.0001)
    }

    func testPinchDistanceClassifierReturnsUnknownForMissingLandmarks() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let observation = classifier.classify(
            HandLandmarkObservation(
                thumbTip: nil,
                indexTip: HandLandmarkPoint(
                    location: NormalizedPoint(x: 0.45, y: 0.50),
                    confidence: 0.90
                ),
                timestamp: 4
            )
        )

        XCTAssertEqual(observation.state, .unknown)
        XCTAssertNil(observation.midpoint)
        XCTAssertNil(observation.normalizedDistance)
        XCTAssertEqual(observation.confidence, 0)
    }

    func testPinchDistanceClassifierReturnsUnknownForLowConfidenceLandmarks() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let observation = classifier.classify(
            HandLandmarkObservation(
                thumbTip: HandLandmarkPoint(
                    location: NormalizedPoint(x: 0.40, y: 0.50),
                    confidence: 0.64
                ),
                indexTip: HandLandmarkPoint(
                    location: NormalizedPoint(x: 0.44, y: 0.50),
                    confidence: 0.90
                ),
                timestamp: 5
            )
        )

        XCTAssertEqual(observation.state, .unknown)
        XCTAssertNil(observation.midpoint)
        XCTAssertNil(observation.normalizedDistance)
    }

    func testPinchDistanceClassifierReturnsUnknownForOutOfBoundsLandmarks() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let observation = classifier.classify(
            landmarkObservation(
                thumb: NormalizedPoint(x: -0.01, y: 0.50),
                index: NormalizedPoint(x: 0.04, y: 0.50)
            )
        )

        XCTAssertEqual(observation.state, .unknown)
        XCTAssertNil(observation.midpoint)
        XCTAssertNil(observation.normalizedDistance)
    }

    func testPinchDistanceClassifierThresholdBoundaries() {
        let classifier = PinchDistanceClassifier(configuration: testPinchConfiguration)

        let pinching = classifier.classify(
            landmarkObservation(
                thumb: NormalizedPoint(x: 0.40, y: 0.50),
                index: NormalizedPoint(x: 0.45, y: 0.50)
            )
        )
        let open = classifier.classify(
            landmarkObservation(
                thumb: NormalizedPoint(x: 0.40, y: 0.50),
                index: NormalizedPoint(x: 0.501, y: 0.50)
            )
        )

        XCTAssertEqual(pinching.state, .pinching)
        XCTAssertEqual(open.state, .open)
    }

    func testPinchStabilityControllerSinglePinchFrameDoesNotEmitStablePinch() {
        let controller = PinchStabilityController(configuration: testPinchStabilityConfiguration)

        XCTAssertNil(controller.process(.pinching(timestamp: 1)))
    }

    func testPinchStabilityControllerRequiredPinchStreakEmitsStablePinch() {
        let controller = PinchStabilityController(configuration: testPinchStabilityConfiguration)

        XCTAssertNil(controller.process(.pinching(timestamp: 1)))
        XCTAssertNil(controller.process(.pinching(timestamp: 2)))
        let result = controller.process(.pinching(timestamp: 3))

        XCTAssertEqual(result?.state, .pinching)
        XCTAssertEqual(result?.timestamp, 3)
    }

    func testPinchStabilityControllerNoisySequenceDoesNotToggle() {
        let controller = PinchStabilityController(configuration: testPinchStabilityConfiguration)

        XCTAssertNil(controller.process(.pinching(timestamp: 1)))
        XCTAssertNil(controller.process(.pinching(timestamp: 2)))
        XCTAssertNil(controller.process(.unknown(timestamp: 3)))
        XCTAssertNil(controller.process(.pinching(timestamp: 4)))
        XCTAssertNil(controller.process(.pinching(timestamp: 5)))

        XCTAssertNil(controller.process(.open(timestamp: 6)))
    }

    func testPinchStabilityControllerRequiredOpenStreakEmitsStableOpen() {
        let controller = PinchStabilityController(configuration: testPinchStabilityConfiguration)

        XCTAssertNil(controller.process(.open(timestamp: 50)))
        XCTAssertNil(controller.process(.open(timestamp: 51)))
        let result = controller.process(.open(timestamp: 52))

        XCTAssertEqual(result?.state, .open)
        XCTAssertEqual(result?.timestamp, 52)
    }

    func testPinchStabilityControllerResetClearsHistory() {
        let controller = PinchStabilityController(configuration: testPinchStabilityConfiguration)

        XCTAssertNil(controller.process(.pinching(timestamp: 60)))
        XCTAssertNil(controller.process(.pinching(timestamp: 61)))
        controller.reset()

        XCTAssertNil(controller.process(.pinching(timestamp: 70)))
        XCTAssertNil(controller.process(.pinching(timestamp: 71)))
        let result = controller.process(.pinching(timestamp: 72))

        XCTAssertEqual(result?.state, .pinching)
    }
}

private let testPinchConfiguration = PinchClassificationConfiguration(
    pinchingDistanceThreshold: 0.05,
    openDistanceThreshold: 0.10,
    minimumLandmarkConfidence: 0.65
)

private let testPinchStabilityConfiguration = PinchStabilityConfiguration(
    requiredPinchingObservations: 3,
    requiredOpenObservations: 3
)

private extension PinchObservation {
    static func pinching(timestamp: TimeInterval) -> PinchObservation {
        PinchObservation(
            state: .pinching,
            thumbTip: nil,
            indexTip: nil,
            midpoint: NormalizedPoint(x: 0.42, y: 0.50),
            normalizedDistance: 0.04,
            confidence: 0.90,
            timestamp: timestamp
        )
    }

    static func open(timestamp: TimeInterval) -> PinchObservation {
        PinchObservation(
            state: .open,
            thumbTip: nil,
            indexTip: nil,
            midpoint: NormalizedPoint(x: 0.40, y: 0.50),
            normalizedDistance: 0.15,
            confidence: 0.90,
            timestamp: timestamp
        )
    }

    static func unknown(timestamp: TimeInterval) -> PinchObservation {
        PinchObservation(
            state: .unknown,
            thumbTip: nil,
            indexTip: nil,
            midpoint: nil,
            normalizedDistance: nil,
            confidence: 0,
            timestamp: timestamp
        )
    }
}

private func landmarkObservation(
    thumb: NormalizedPoint,
    index: NormalizedPoint,
    thumbConfidence: Double = 0.90,
    indexConfidence: Double = 0.92,
    timestamp: TimeInterval = 4
) -> HandLandmarkObservation {
    HandLandmarkObservation(
        thumbTip: HandLandmarkPoint(
            location: thumb,
            confidence: thumbConfidence
        ),
        indexTip: HandLandmarkPoint(
            location: index,
            confidence: indexConfidence
        ),
        timestamp: timestamp
    )
}
