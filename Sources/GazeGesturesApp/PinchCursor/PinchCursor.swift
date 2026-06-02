import Foundation

struct NormalizedPoint: Equatable {
    var x: Double
    var y: Double

    var isWithinUnitBounds: Bool {
        (0...1).contains(x) && (0...1).contains(y)
    }
}

struct HandLandmarkPoint: Equatable {
    var location: NormalizedPoint
    var confidence: Double
}

struct HandLandmarkObservation: Equatable {
    var thumbTip: HandLandmarkPoint?
    var indexTip: HandLandmarkPoint?
    var timestamp: TimeInterval

    var hasRequiredPinchLandmarks: Bool {
        thumbTip != nil && indexTip != nil
    }
}

enum PinchState: Equatable {
    case unknown
    case open
    case pinching
}

struct PinchObservation: Equatable {
    var state: PinchState
    var thumbTip: HandLandmarkPoint?
    var indexTip: HandLandmarkPoint?
    var midpoint: NormalizedPoint?
    var normalizedDistance: Double?
    var confidence: Double
    var timestamp: TimeInterval
}

struct PinchClassificationConfiguration: Equatable {
    var pinchingDistanceThreshold: Double
    var openDistanceThreshold: Double
    var minimumLandmarkConfidence: Double

    static let conservativeDefault = PinchClassificationConfiguration(
        pinchingDistanceThreshold: 0.055,
        openDistanceThreshold: 0.095,
        minimumLandmarkConfidence: 0.65
    )
}

struct PinchCursorPoint: Equatable {
    var normalizedPoint: NormalizedPoint
    var confidence: Double
    var timestamp: TimeInterval
}

struct PinchDistanceClassifier {
    var configuration: PinchClassificationConfiguration

    init(configuration: PinchClassificationConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func classify(_ observation: HandLandmarkObservation) -> PinchObservation {
        guard let thumbTip = observation.thumbTip,
              let indexTip = observation.indexTip else {
            return unknownObservation(from: observation)
        }

        guard thumbTip.confidence >= configuration.minimumLandmarkConfidence,
              indexTip.confidence >= configuration.minimumLandmarkConfidence,
              thumbTip.location.isWithinUnitBounds,
              indexTip.location.isWithinUnitBounds else {
            return unknownObservation(from: observation)
        }

        let distance = normalizedDistance(from: thumbTip.location, to: indexTip.location)
        let confidence = min(thumbTip.confidence, indexTip.confidence)
        let midpoint = NormalizedPoint(
            x: (thumbTip.location.x + indexTip.location.x) / 2,
            y: (thumbTip.location.y + indexTip.location.y) / 2
        )

        return PinchObservation(
            state: state(forDistance: distance),
            thumbTip: thumbTip,
            indexTip: indexTip,
            midpoint: midpoint,
            normalizedDistance: distance,
            confidence: confidence,
            timestamp: observation.timestamp
        )
    }

    private func state(forDistance distance: Double) -> PinchState {
        if distance <= configuration.pinchingDistanceThreshold {
            return .pinching
        }

        if distance >= configuration.openDistanceThreshold {
            return .open
        }

        return .unknown
    }

    private func normalizedDistance(from lhs: NormalizedPoint, to rhs: NormalizedPoint) -> Double {
        let deltaX = lhs.x - rhs.x
        let deltaY = lhs.y - rhs.y

        return (deltaX * deltaX + deltaY * deltaY).squareRoot()
    }

    private func unknownObservation(from observation: HandLandmarkObservation) -> PinchObservation {
        PinchObservation(
            state: .unknown,
            thumbTip: observation.thumbTip,
            indexTip: observation.indexTip,
            midpoint: nil,
            normalizedDistance: nil,
            confidence: 0,
            timestamp: observation.timestamp
        )
    }
}
