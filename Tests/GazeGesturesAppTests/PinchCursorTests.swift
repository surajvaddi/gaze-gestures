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
}
