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
