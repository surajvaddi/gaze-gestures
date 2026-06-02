import CoreGraphics
import CoreMedia
import Foundation
import Vision

protocol HandLandmarkDetecting: AnyObject {
    var onObservation: ((HandLandmarkObservation) -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }

    func startDetection()
    func stopDetection()
    func process(_ frame: CameraFrame)
}

protocol HandLandmarkRequestRunning {
    func landmarkObservation(in frame: CameraFrame) throws -> HandLandmarkObservation
}

final class VisionHandLandmarkDetector: HandLandmarkDetecting {
    var onObservation: ((HandLandmarkObservation) -> Void)?
    var onFailure: ((String) -> Void)?

    private let requestRunner: HandLandmarkRequestRunning
    private var isRunning = false

    init(requestRunner: HandLandmarkRequestRunning = VisionHandLandmarkRequestRunner()) {
        self.requestRunner = requestRunner
    }

    func startDetection() {
        isRunning = true
    }

    func stopDetection() {
        isRunning = false
    }

    func process(_ frame: CameraFrame) {
        guard isRunning else { return }

        do {
            let observation = try requestRunner.landmarkObservation(in: frame)
            onObservation?(observation)
        } catch {
            onFailure?(error.localizedDescription)
        }
    }
}

struct VisionHandLandmarkRequestRunner: HandLandmarkRequestRunning {
    var minimumLandmarkConfidence: Double = PinchClassificationConfiguration
        .conservativeDefault
        .minimumLandmarkConfidence

    func landmarkObservation(in frame: CameraFrame) throws -> HandLandmarkObservation {
        guard let sampleBuffer = frame.sampleBuffer else {
            throw VisionHandLandmarkError.missingSampleBuffer
        }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )
        try handler.perform([request])

        guard let hand = request.results?.first else {
            return HandLandmarkObservation(
                thumbTip: nil,
                indexTip: nil,
                timestamp: frame.timestamp
            )
        }

        return try landmarkObservation(from: hand, timestamp: frame.timestamp)
    }

    func landmarkObservation(
        from hand: VNHumanHandPoseObservation,
        timestamp: TimeInterval
    ) throws -> HandLandmarkObservation {
        HandLandmarkObservation(
            thumbTip: try landmarkPoint(from: hand, joint: .thumbTip),
            indexTip: try landmarkPoint(from: hand, joint: .indexTip),
            timestamp: timestamp
        )
    }

    private func landmarkPoint(
        from hand: VNHumanHandPoseObservation,
        joint: VNHumanHandPoseObservation.JointName
    ) throws -> HandLandmarkPoint? {
        let recognizedPoint = try hand.recognizedPoint(joint)
        let confidence = Double(recognizedPoint.confidence)

        guard confidence >= minimumLandmarkConfidence else {
            return nil
        }

        return HandLandmarkPoint(
            location: NormalizedPoint(
                x: Double(recognizedPoint.location.x),
                y: Double(recognizedPoint.location.y)
            ),
            confidence: confidence
        )
    }
}

private enum VisionHandLandmarkError: LocalizedError {
    case missingSampleBuffer

    var errorDescription: String? {
        switch self {
        case .missingSampleBuffer:
            return "Camera frame sample buffer is unavailable"
        }
    }
}
