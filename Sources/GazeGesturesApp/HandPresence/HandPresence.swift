import Foundation

protocol HandPresenceDetecting: AnyObject {
    var onObservation: ((HandPresenceObservation) -> Void)? { get set }

    func startDetection()
    func stopDetection()
    func process(_ frame: CameraFrame)
}

enum HandPresenceState: Equatable {
    case unknown
    case present
    case absent
    case failed(String)

    var failureMessage: String? {
        guard case .failed(let message) = self else {
            return nil
        }

        return message
    }
}

struct HandPresenceObservation: Equatable {
    var state: HandPresenceState
    var confidence: Double
    var timestamp: TimeInterval

    init(
        state: HandPresenceState,
        confidence: Double,
        timestamp: TimeInterval
    ) {
        self.state = state
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

struct HandPresenceStabilityConfiguration: Equatable {
    var requiredPresentObservations: Int
    var requiredAbsentObservations: Int
    var minimumPresentConfidence: Double
    var minimumAbsentConfidence: Double

    static let conservativeDefault = HandPresenceStabilityConfiguration(
        requiredPresentObservations: 4,
        requiredAbsentObservations: 12,
        minimumPresentConfidence: 0.70,
        minimumAbsentConfidence: 0.60
    )
}

final class HandPresenceSessionController {
    private let configuration: HandPresenceStabilityConfiguration
    private var presentObservationCount = 0
    private var absentObservationCount = 0

    init(configuration: HandPresenceStabilityConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func process(_ observation: HandPresenceObservation) -> HandPresenceObservation? {
        switch observation.state {
        case .present:
            return processPresentObservation(observation)
        case .absent:
            return processAbsentObservation(observation)
        case .failed:
            resetCounts()
            return observation
        case .unknown:
            resetCounts()
            return nil
        }
    }

    func reset() {
        resetCounts()
    }

    private func processPresentObservation(
        _ observation: HandPresenceObservation
    ) -> HandPresenceObservation? {
        guard observation.confidence >= configuration.minimumPresentConfidence else {
            presentObservationCount = 0
            return nil
        }

        presentObservationCount += 1
        absentObservationCount = 0

        guard presentObservationCount >= configuration.requiredPresentObservations else {
            return nil
        }

        return observation
    }

    private func processAbsentObservation(
        _ observation: HandPresenceObservation
    ) -> HandPresenceObservation? {
        guard observation.confidence >= configuration.minimumAbsentConfidence else {
            absentObservationCount = 0
            return nil
        }

        absentObservationCount += 1
        presentObservationCount = 0

        guard absentObservationCount >= configuration.requiredAbsentObservations else {
            return nil
        }

        return observation
    }

    private func resetCounts() {
        presentObservationCount = 0
        absentObservationCount = 0
    }
}
