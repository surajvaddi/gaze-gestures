import CoreMedia
import Foundation
import Vision

protocol HandPresenceRequestRunning {
    func detectedHandCount(in frame: CameraFrame) throws -> Int
}

final class VisionHandPresenceDetector: HandPresenceDetecting {
    var onObservation: ((HandPresenceObservation) -> Void)?

    private let requestRunner: HandPresenceRequestRunning
    private var isRunning = false

    init(requestRunner: HandPresenceRequestRunning = VisionHandPresenceRequestRunner()) {
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
            let handCount = try requestRunner.detectedHandCount(in: frame)
            onObservation?(
                HandPresenceObservation(
                    state: handCount > 0 ? .present : .absent,
                    confidence: 1,
                    timestamp: frame.timestamp
                )
            )
        } catch {
            onObservation?(
                HandPresenceObservation(
                    state: .failed(error.localizedDescription),
                    confidence: 0,
                    timestamp: frame.timestamp
                )
            )
        }
    }
}

struct VisionHandPresenceRequestRunner: HandPresenceRequestRunning {
    func detectedHandCount(in frame: CameraFrame) throws -> Int {
        guard let sampleBuffer = frame.sampleBuffer else {
            throw VisionHandPresenceError.missingSampleBuffer
        }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )
        try handler.perform([request])

        return request.results?.count ?? 0
    }
}

private enum VisionHandPresenceError: LocalizedError {
    case missingSampleBuffer

    var errorDescription: String? {
        switch self {
        case .missingSampleBuffer:
            return "Camera frame sample buffer is unavailable"
        }
    }
}
