import XCTest
@testable import GazeGesturesApp

final class HandPresenceTests: XCTestCase {
    func testHandPresenceStateEquality() {
        XCTAssertEqual(HandPresenceState.unknown, .unknown)
        XCTAssertEqual(HandPresenceState.present, .present)
        XCTAssertEqual(HandPresenceState.absent, .absent)
        XCTAssertEqual(HandPresenceState.failed("Vision unavailable"), .failed("Vision unavailable"))

        XCTAssertNotEqual(HandPresenceState.present, .absent)
        XCTAssertNotEqual(HandPresenceState.failed("A"), .failed("B"))
    }

    func testFailureMessagePropagation() {
        XCTAssertNil(HandPresenceState.unknown.failureMessage)
        XCTAssertNil(HandPresenceState.present.failureMessage)
        XCTAssertNil(HandPresenceState.absent.failureMessage)
        XCTAssertEqual(
            HandPresenceState.failed("Hand pose request failed").failureMessage,
            "Hand pose request failed"
        )
    }

    func testObservationEquality() {
        let observation = HandPresenceObservation(
            state: .present,
            confidence: 0.82,
            timestamp: 10.5
        )

        XCTAssertEqual(
            observation,
            HandPresenceObservation(
                state: .present,
                confidence: 0.82,
                timestamp: 10.5
            )
        )
        XCTAssertNotEqual(
            observation,
            HandPresenceObservation(
                state: .present,
                confidence: 0.83,
                timestamp: 10.5
            )
        )
    }

    func testConservativeStabilityDefaultsAreExplicit() {
        let configuration = HandPresenceStabilityConfiguration.conservativeDefault

        XCTAssertEqual(configuration.requiredPresentObservations, 4)
        XCTAssertEqual(configuration.requiredAbsentObservations, 12)
        XCTAssertEqual(configuration.minimumPresentConfidence, 0.70)
        XCTAssertEqual(configuration.minimumAbsentConfidence, 0.60)
    }

    func testCustomStabilityConfigurationEquality() {
        let configuration = HandPresenceStabilityConfiguration(
            requiredPresentObservations: 3,
            requiredAbsentObservations: 8,
            minimumPresentConfidence: 0.65,
            minimumAbsentConfidence: 0.55
        )

        XCTAssertEqual(
            configuration,
            HandPresenceStabilityConfiguration(
                requiredPresentObservations: 3,
                requiredAbsentObservations: 8,
                minimumPresentConfidence: 0.65,
                minimumAbsentConfidence: 0.55
            )
        )
    }

    func testDetectorProtocolDeliversObservationWhenRunning() {
        let detector = StubHandPresenceDetector()
        var received: HandPresenceObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.publish(
            HandPresenceObservation(
                state: .present,
                confidence: 0.78,
                timestamp: 20
            )
        )

        XCTAssertTrue(detector.isRunning)
        XCTAssertEqual(
            received,
            HandPresenceObservation(
                state: .present,
                confidence: 0.78,
                timestamp: 20
            )
        )
    }

    func testDetectorProtocolIgnoresObservationAfterStop() {
        let detector = StubHandPresenceDetector()
        var receivedObservations: [HandPresenceObservation] = []
        detector.onObservation = { observation in
            receivedObservations.append(observation)
        }

        detector.startDetection()
        detector.stopDetection()
        detector.publish(
            HandPresenceObservation(
                state: .present,
                confidence: 0.78,
                timestamp: 20
            )
        )

        XCTAssertFalse(detector.isRunning)
        XCTAssertTrue(receivedObservations.isEmpty)
    }

    func testDetectorProtocolPropagatesFailureObservation() {
        let detector = StubHandPresenceDetector()
        var received: HandPresenceObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.publish(
            HandPresenceObservation(
                state: .failed("Vision request failed"),
                confidence: 0,
                timestamp: 30
            )
        )

        XCTAssertEqual(received?.state.failureMessage, "Vision request failed")
        XCTAssertEqual(
            received,
            HandPresenceObservation(
                state: .failed("Vision request failed"),
                confidence: 0,
                timestamp: 30
            )
        )
    }

    func testSessionControllerSinglePresentObservationDoesNotEmitStablePresent() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        let result = controller.process(.present(confidence: 0.80, timestamp: 1))

        XCTAssertNil(result)
    }

    func testSessionControllerRequiredPresentObservationsEmitStablePresent() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        XCTAssertNil(controller.process(.present(confidence: 0.80, timestamp: 1)))
        XCTAssertNil(controller.process(.present(confidence: 0.81, timestamp: 2)))
        let result = controller.process(.present(confidence: 0.82, timestamp: 3))

        XCTAssertEqual(result, .present(confidence: 0.82, timestamp: 3))
    }

    func testSessionControllerLowConfidencePresentDoesNotCount() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        XCTAssertNil(controller.process(.present(confidence: 0.80, timestamp: 1)))
        XCTAssertNil(controller.process(.present(confidence: 0.69, timestamp: 2)))
        XCTAssertNil(controller.process(.present(confidence: 0.80, timestamp: 3)))
        XCTAssertNil(controller.process(.present(confidence: 0.81, timestamp: 4)))
        let result = controller.process(.present(confidence: 0.82, timestamp: 5))

        XCTAssertEqual(result, .present(confidence: 0.82, timestamp: 5))
    }

    func testSessionControllerAbsentObservationResetsPresentProgress() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        XCTAssertNil(controller.process(.present(confidence: 0.80, timestamp: 1)))
        XCTAssertNil(controller.process(.present(confidence: 0.81, timestamp: 2)))
        XCTAssertNil(controller.process(.absent(confidence: 0.70, timestamp: 3)))
        XCTAssertNil(controller.process(.present(confidence: 0.82, timestamp: 4)))
        XCTAssertNil(controller.process(.present(confidence: 0.83, timestamp: 5)))
        let result = controller.process(.present(confidence: 0.84, timestamp: 6))

        XCTAssertEqual(result, .present(confidence: 0.84, timestamp: 6))
    }

    func testSessionControllerRequiredAbsentObservationsEmitStableAbsent() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        XCTAssertNil(controller.process(.absent(confidence: 0.70, timestamp: 1)))
        let result = controller.process(.absent(confidence: 0.71, timestamp: 2))

        XCTAssertEqual(result, .absent(confidence: 0.71, timestamp: 2))
    }

    func testSessionControllerLowConfidenceAbsentDoesNotCount() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        XCTAssertNil(controller.process(.absent(confidence: 0.70, timestamp: 1)))
        XCTAssertNil(controller.process(.absent(confidence: 0.59, timestamp: 2)))
        XCTAssertNil(controller.process(.absent(confidence: 0.70, timestamp: 3)))
        let result = controller.process(.absent(confidence: 0.71, timestamp: 4))

        XCTAssertEqual(result, .absent(confidence: 0.71, timestamp: 4))
    }

    func testSessionControllerFailureObservationEmitsImmediately() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        let result = controller.process(
            HandPresenceObservation(
                state: .failed("Vision request failed"),
                confidence: 0,
                timestamp: 1
            )
        )

        XCTAssertEqual(
            result,
            HandPresenceObservation(
                state: .failed("Vision request failed"),
                confidence: 0,
                timestamp: 1
            )
        )
    }

    func testSessionControllerUnknownObservationResetsProgressWithoutEmitting() {
        let controller = HandPresenceSessionController(configuration: testConfiguration)

        XCTAssertNil(controller.process(.present(confidence: 0.80, timestamp: 1)))
        XCTAssertNil(controller.process(.present(confidence: 0.81, timestamp: 2)))
        XCTAssertNil(
            controller.process(
                HandPresenceObservation(
                    state: .unknown,
                    confidence: 0,
                    timestamp: 3
                )
            )
        )
        XCTAssertNil(controller.process(.present(confidence: 0.82, timestamp: 4)))
        XCTAssertNil(controller.process(.present(confidence: 0.83, timestamp: 5)))
        let result = controller.process(.present(confidence: 0.84, timestamp: 6))

        XCTAssertEqual(result, .present(confidence: 0.84, timestamp: 6))
    }
}

private let testConfiguration = HandPresenceStabilityConfiguration(
    requiredPresentObservations: 3,
    requiredAbsentObservations: 2,
    minimumPresentConfidence: 0.70,
    minimumAbsentConfidence: 0.60
)

private extension HandPresenceObservation {
    static func present(confidence: Double, timestamp: TimeInterval) -> HandPresenceObservation {
        HandPresenceObservation(
            state: .present,
            confidence: confidence,
            timestamp: timestamp
        )
    }

    static func absent(confidence: Double, timestamp: TimeInterval) -> HandPresenceObservation {
        HandPresenceObservation(
            state: .absent,
            confidence: confidence,
            timestamp: timestamp
        )
    }
}

private final class StubHandPresenceDetector: HandPresenceDetecting {
    var onObservation: ((HandPresenceObservation) -> Void)?
    private(set) var isRunning = false

    func startDetection() {
        isRunning = true
    }

    func stopDetection() {
        isRunning = false
    }

    func publish(_ observation: HandPresenceObservation) {
        guard isRunning else { return }

        onObservation?(observation)
    }
}
