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

enum PinchRejectionReason: Equatable {
    case insufficientObservations
    case unknownObservation
    case noisyMixedStates
    case lowConfidence
    case missingScreenBounds
    case mappingFailed
    case cooldownActive
}

enum TemporalPinchClassificationResult: Equatable {
    case accepted(PinchObservation)
    case rejected(PinchRejectionReason)
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

struct PinchStabilityConfiguration: Equatable {
    var requiredPinchingObservations: Int
    var requiredOpenObservations: Int

    static let conservativeDefault = PinchStabilityConfiguration(
        requiredPinchingObservations: 3,
        requiredOpenObservations: 3
    )
}

struct PinchCursorMappingConfiguration: Equatable {
    var minimumConfidence: Double
    var mirrorsHorizontally: Bool
    var invertsVertically: Bool
    var requiredState: PinchState?

    static let conservativeDefault = PinchCursorMappingConfiguration(
        minimumConfidence: PinchClassificationConfiguration.conservativeDefault.minimumLandmarkConfidence,
        mirrorsHorizontally: true,
        invertsVertically: false,
        requiredState: .pinching
    )
}

struct PinchCursorSmoothingConfiguration: Equatable {
    var interpolationFactor: Double

    static let conservativeDefault = PinchCursorSmoothingConfiguration(
        interpolationFactor: 0.35
    )
}

struct PinchObservationBufferConfiguration: Equatable {
    var capacity: Int

    static let conservativeDefault = PinchObservationBufferConfiguration(
        capacity: 6
    )
}

struct TemporalPinchClassifierConfiguration: Equatable {
    var requiredPinchingObservations: Int
    var requiredOpenObservations: Int
    var minimumAverageConfidence: Double

    static let conservativeDefault = TemporalPinchClassifierConfiguration(
        requiredPinchingObservations: 4,
        requiredOpenObservations: 3,
        minimumAverageConfidence: 0.70
    )
}

struct PinchCursorPoint: Equatable {
    var normalizedPoint: NormalizedPoint
    var confidence: Double
    var timestamp: TimeInterval
}

struct ScreenPoint: Equatable {
    var x: Double
    var y: Double
}

struct ScreenBounds: Equatable {
    var origin: ScreenPoint
    var width: Double
    var height: Double

    var isValid: Bool {
        width > 0 && height > 0
    }
}

protocol ScreenBoundsProviding {
    func currentScreenBounds() -> ScreenBounds?
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

final class PinchStabilityController {
    private let configuration: PinchStabilityConfiguration
    private var pinchingObservationCount = 0
    private var openObservationCount = 0

    init(configuration: PinchStabilityConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func process(_ observation: PinchObservation) -> PinchObservation? {
        switch observation.state {
        case .pinching:
            pinchingObservationCount += 1
            openObservationCount = 0

            guard pinchingObservationCount >= configuration.requiredPinchingObservations else {
                return nil
            }

            return observation
        case .open:
            openObservationCount += 1
            pinchingObservationCount = 0

            guard openObservationCount >= configuration.requiredOpenObservations else {
                return nil
            }

            return observation
        case .unknown:
            reset()
            return nil
        }
    }

    func reset() {
        pinchingObservationCount = 0
        openObservationCount = 0
    }
}

struct PinchCursorMapper {
    var configuration: PinchCursorMappingConfiguration

    init(configuration: PinchCursorMappingConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func map(_ observation: PinchObservation, in bounds: ScreenBounds) -> ScreenPoint? {
        guard bounds.isValid,
              observation.confidence >= configuration.minimumConfidence,
              let midpoint = observation.midpoint else {
            return nil
        }

        if let requiredState = configuration.requiredState,
           observation.state != requiredState {
            return nil
        }

        return map(
            PinchCursorPoint(
                normalizedPoint: midpoint,
                confidence: observation.confidence,
                timestamp: observation.timestamp
            ),
            in: bounds
        )
    }

    func map(_ point: PinchCursorPoint, in bounds: ScreenBounds) -> ScreenPoint? {
        guard bounds.isValid,
              point.confidence >= configuration.minimumConfidence else {
            return nil
        }

        let normalizedPoint = clamped(point.normalizedPoint)
        let mappedX = configuration.mirrorsHorizontally ? 1 - normalizedPoint.x : normalizedPoint.x
        let mappedY = configuration.invertsVertically ? 1 - normalizedPoint.y : normalizedPoint.y

        return ScreenPoint(
            x: bounds.origin.x + mappedX * bounds.width,
            y: bounds.origin.y + mappedY * bounds.height
        )
    }

    private func clamped(_ point: NormalizedPoint) -> NormalizedPoint {
        NormalizedPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }
}

final class PinchCursorSmoother {
    private let configuration: PinchCursorSmoothingConfiguration
    private var lastPoint: ScreenPoint?

    init(configuration: PinchCursorSmoothingConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func smooth(_ point: ScreenPoint) -> ScreenPoint {
        guard let lastPoint else {
            self.lastPoint = point
            return point
        }

        let factor = clampedInterpolationFactor
        let smoothedPoint = ScreenPoint(
            x: lastPoint.x + (point.x - lastPoint.x) * factor,
            y: lastPoint.y + (point.y - lastPoint.y) * factor
        )

        self.lastPoint = smoothedPoint
        return smoothedPoint
    }

    func reset() {
        lastPoint = nil
    }

    private var clampedInterpolationFactor: Double {
        min(max(configuration.interpolationFactor, 0), 1)
    }
}

final class PinchObservationBuffer {
    private let configuration: PinchObservationBufferConfiguration
    private var observations: [PinchObservation] = []

    init(configuration: PinchObservationBufferConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func append(_ observation: PinchObservation) {
        observations.append(observation)
        trimToCapacity()
    }

    func allObservations() -> [PinchObservation] {
        observations
    }

    func observations(matching state: PinchState) -> [PinchObservation] {
        observations.filter { $0.state == state }
    }

    func reset() {
        observations.removeAll()
    }

    private func trimToCapacity() {
        let capacity = max(configuration.capacity, 0)

        guard observations.count > capacity else {
            return
        }

        observations.removeFirst(observations.count - capacity)
    }
}

struct TemporalPinchClassifier {
    var configuration: TemporalPinchClassifierConfiguration

    init(configuration: TemporalPinchClassifierConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func classify(_ observations: [PinchObservation]) -> PinchObservation? {
        guard case .accepted(let observation) = evaluate(observations) else {
            return nil
        }

        return observation
    }

    func evaluate(_ observations: [PinchObservation]) -> TemporalPinchClassificationResult {
        guard !observations.isEmpty else {
            return .rejected(.insufficientObservations)
        }

        guard !observations.contains(where: { $0.state == .unknown }) else {
            return .rejected(.unknownObservation)
        }

        if let pinching = stableObservation(
            in: observations,
            state: .pinching,
            requiredCount: configuration.requiredPinchingObservations
        ) {
            return .accepted(pinching)
        }

        if let open = stableObservation(
            in: observations,
            state: .open,
            requiredCount: configuration.requiredOpenObservations
        ) {
            return .accepted(open)
        }

        if containsOnlySupportedState(observations),
           averageConfidence(in: observations) < configuration.minimumAverageConfidence {
            return .rejected(.lowConfidence)
        }

        if !containsOnlySupportedState(observations) {
            return .rejected(.noisyMixedStates)
        }

        return .rejected(.insufficientObservations)
    }

    private func stableObservation(
        in observations: [PinchObservation],
        state: PinchState,
        requiredCount: Int
    ) -> PinchObservation? {
        let matching = observations.filter { $0.state == state }

        guard requiredCount > 0,
              matching.count >= requiredCount,
              matching.count == observations.count,
              averageConfidence(in: matching) >= configuration.minimumAverageConfidence else {
            return nil
        }

        return matching.last
    }

    private func averageConfidence(in observations: [PinchObservation]) -> Double {
        guard !observations.isEmpty else {
            return 0
        }

        let total = observations.reduce(0) { partialResult, observation in
            partialResult + observation.confidence
        }

        return total / Double(observations.count)
    }

    private func containsOnlySupportedState(_ observations: [PinchObservation]) -> Bool {
        guard let firstState = observations.first?.state else {
            return false
        }

        return observations.allSatisfy { $0.state == firstState }
    }
}
