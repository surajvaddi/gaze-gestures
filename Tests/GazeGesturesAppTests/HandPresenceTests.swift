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
}
