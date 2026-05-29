import Foundation

protocol HandPresenceDetecting: AnyObject {
    var onObservation: ((HandPresenceObservation) -> Void)? { get set }

    func startDetection()
    func stopDetection()
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
