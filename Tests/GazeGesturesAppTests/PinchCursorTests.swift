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

    func testConservativePinchCursorMappingDefaultsAreExplicit() {
        let configuration = PinchCursorMappingConfiguration.conservativeDefault

        XCTAssertEqual(configuration.minimumConfidence, 0.65)
        XCTAssertTrue(configuration.mirrorsHorizontally)
        XCTAssertFalse(configuration.invertsVertically)
        XCTAssertEqual(configuration.requiredState, .pinching)
    }

    func testConservativePinchCursorSmoothingDefaultsAreExplicit() {
        let configuration = PinchCursorSmoothingConfiguration.conservativeDefault

        XCTAssertEqual(configuration.interpolationFactor, 0.35)
    }

    func testConservativePinchObservationBufferDefaultsAreExplicit() {
        let configuration = PinchObservationBufferConfiguration.conservativeDefault

        XCTAssertEqual(configuration.capacity, 6)
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

    func testPinchCursorMapperMapsStablePinchMidpointIntoScreenBounds() {
        let mapper = PinchCursorMapper(configuration: directPinchCursorMappingConfiguration)
        let bounds = ScreenBounds(
            origin: ScreenPoint(x: 100, y: 200),
            width: 100,
            height: 40
        )

        let point = mapper.map(.pinching(timestamp: 80), in: bounds)

        XCTAssertEqual(point, ScreenPoint(x: 142, y: 220))
    }

    func testPinchCursorMapperMirrorsAndInvertsCoordinatesWhenConfigured() {
        let mapper = PinchCursorMapper(
            configuration: PinchCursorMappingConfiguration(
                minimumConfidence: 0.65,
                mirrorsHorizontally: true,
                invertsVertically: true,
                requiredState: .pinching
            )
        )
        let bounds = ScreenBounds(
            origin: ScreenPoint(x: 0, y: 0),
            width: 100,
            height: 40
        )

        let point = mapper.map(.pinching(timestamp: 81), in: bounds)

        XCTAssertEqual(point?.x ?? -1, 58, accuracy: 0.0001)
        XCTAssertEqual(point?.y ?? -1, 20, accuracy: 0.0001)
    }

    func testPinchCursorMapperClampsNormalizedPointToScreenBounds() {
        let mapper = PinchCursorMapper(configuration: directPinchCursorMappingConfiguration)
        let bounds = ScreenBounds(
            origin: ScreenPoint(x: 10, y: 20),
            width: 100,
            height: 30
        )
        let cursorPoint = PinchCursorPoint(
            normalizedPoint: NormalizedPoint(x: 1.25, y: -0.50),
            confidence: 0.90,
            timestamp: 82
        )

        let point = mapper.map(cursorPoint, in: bounds)

        XCTAssertEqual(point, ScreenPoint(x: 110, y: 20))
    }

    func testPinchCursorMapperRejectsOpenObservationByDefault() {
        let mapper = PinchCursorMapper(configuration: directPinchCursorMappingConfiguration)

        XCTAssertNil(mapper.map(.open(timestamp: 83), in: testScreenBounds))
    }

    func testPinchCursorMapperRejectsLowConfidenceObservation() {
        let mapper = PinchCursorMapper(configuration: directPinchCursorMappingConfiguration)
        let observation = PinchObservation(
            state: .pinching,
            thumbTip: nil,
            indexTip: nil,
            midpoint: NormalizedPoint(x: 0.50, y: 0.50),
            normalizedDistance: 0.04,
            confidence: 0.64,
            timestamp: 84
        )

        XCTAssertNil(mapper.map(observation, in: testScreenBounds))
    }

    func testPinchCursorMapperRejectsMissingMidpoint() {
        let mapper = PinchCursorMapper(configuration: directPinchCursorMappingConfiguration)

        XCTAssertNil(mapper.map(.unknown(timestamp: 85), in: testScreenBounds))
    }

    func testPinchCursorMapperRejectsInvalidBounds() {
        let mapper = PinchCursorMapper(configuration: directPinchCursorMappingConfiguration)
        let bounds = ScreenBounds(
            origin: ScreenPoint(x: 0, y: 0),
            width: 0,
            height: 30
        )

        XCTAssertNil(mapper.map(.pinching(timestamp: 86), in: bounds))
    }

    func testPinchCursorSmootherReturnsFirstPointImmediately() {
        let smoother = PinchCursorSmoother(configuration: testSmoothingConfiguration)
        let point = ScreenPoint(x: 20, y: 30)

        XCTAssertEqual(smoother.smooth(point), point)
    }

    func testPinchCursorSmootherInterpolatesTowardNextPoint() {
        let smoother = PinchCursorSmoother(configuration: testSmoothingConfiguration)

        _ = smoother.smooth(ScreenPoint(x: 0, y: 10))
        let point = smoother.smooth(ScreenPoint(x: 100, y: 50))

        XCTAssertEqual(point, ScreenPoint(x: 25, y: 20))
    }

    func testPinchCursorSmootherUsesPreviousSmoothedPointForNextFrame() {
        let smoother = PinchCursorSmoother(configuration: testSmoothingConfiguration)

        _ = smoother.smooth(ScreenPoint(x: 0, y: 0))
        _ = smoother.smooth(ScreenPoint(x: 100, y: 0))
        let point = smoother.smooth(ScreenPoint(x: 100, y: 0))

        XCTAssertEqual(point, ScreenPoint(x: 43.75, y: 0))
    }

    func testPinchCursorSmootherResetClearsHistory() {
        let smoother = PinchCursorSmoother(configuration: testSmoothingConfiguration)

        _ = smoother.smooth(ScreenPoint(x: 0, y: 0))
        _ = smoother.smooth(ScreenPoint(x: 100, y: 100))
        smoother.reset()

        XCTAssertEqual(smoother.smooth(ScreenPoint(x: 10, y: 20)), ScreenPoint(x: 10, y: 20))
    }

    func testPinchCursorSmootherClampsInterpolationFactor() {
        let fastSmoother = PinchCursorSmoother(
            configuration: PinchCursorSmoothingConfiguration(interpolationFactor: 2)
        )
        let lockedSmoother = PinchCursorSmoother(
            configuration: PinchCursorSmoothingConfiguration(interpolationFactor: -1)
        )

        _ = fastSmoother.smooth(ScreenPoint(x: 0, y: 0))
        _ = lockedSmoother.smooth(ScreenPoint(x: 0, y: 0))

        XCTAssertEqual(fastSmoother.smooth(ScreenPoint(x: 50, y: 60)), ScreenPoint(x: 50, y: 60))
        XCTAssertEqual(lockedSmoother.smooth(ScreenPoint(x: 50, y: 60)), ScreenPoint(x: 0, y: 0))
    }

    func testPinchObservationBufferKeepsNewestObservationsWithinCapacity() {
        let buffer = PinchObservationBuffer(
            configuration: PinchObservationBufferConfiguration(capacity: 3)
        )

        buffer.append(.pinching(timestamp: 1))
        buffer.append(.open(timestamp: 2))
        buffer.append(.unknown(timestamp: 3))
        buffer.append(.pinching(timestamp: 4))

        XCTAssertEqual(buffer.allObservations().map(\.timestamp), [2, 3, 4])
    }

    func testPinchObservationBufferPreservesInsertionOrder() {
        let buffer = PinchObservationBuffer(
            configuration: PinchObservationBufferConfiguration(capacity: 4)
        )

        buffer.append(.open(timestamp: 10))
        buffer.append(.pinching(timestamp: 11))
        buffer.append(.open(timestamp: 12))

        XCTAssertEqual(buffer.allObservations().map(\.timestamp), [10, 11, 12])
    }

    func testPinchObservationBufferFiltersByState() {
        let buffer = PinchObservationBuffer(
            configuration: PinchObservationBufferConfiguration(capacity: 5)
        )

        buffer.append(.pinching(timestamp: 20))
        buffer.append(.open(timestamp: 21))
        buffer.append(.pinching(timestamp: 22))

        XCTAssertEqual(buffer.observations(matching: .pinching).map(\.timestamp), [20, 22])
        XCTAssertEqual(buffer.observations(matching: .open).map(\.timestamp), [21])
        XCTAssertTrue(buffer.observations(matching: .unknown).isEmpty)
    }

    func testPinchObservationBufferResetClearsObservations() {
        let buffer = PinchObservationBuffer(
            configuration: PinchObservationBufferConfiguration(capacity: 3)
        )

        buffer.append(.pinching(timestamp: 30))
        buffer.append(.open(timestamp: 31))
        buffer.reset()

        XCTAssertTrue(buffer.allObservations().isEmpty)
    }

    func testPinchObservationBufferZeroCapacityStoresNoObservations() {
        let buffer = PinchObservationBuffer(
            configuration: PinchObservationBufferConfiguration(capacity: 0)
        )

        buffer.append(.pinching(timestamp: 40))

        XCTAssertTrue(buffer.allObservations().isEmpty)
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

private let directPinchCursorMappingConfiguration = PinchCursorMappingConfiguration(
    minimumConfidence: 0.65,
    mirrorsHorizontally: false,
    invertsVertically: false,
    requiredState: .pinching
)

private let testScreenBounds = ScreenBounds(
    origin: ScreenPoint(x: 0, y: 0),
    width: 100,
    height: 30
)

private let testSmoothingConfiguration = PinchCursorSmoothingConfiguration(
    interpolationFactor: 0.25
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
