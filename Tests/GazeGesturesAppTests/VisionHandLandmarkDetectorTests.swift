import XCTest
@testable import GazeGesturesApp

final class VisionHandLandmarkDetectorTests: XCTestCase {
    func testSuccessfulLandmarkResultEmitsThumbAndIndexObservation() {
        let runner = StubHandLandmarkRequestRunner(
            result: .success(
                HandLandmarkObservation(
                    thumbTip: HandLandmarkPoint(
                        location: NormalizedPoint(x: 0.40, y: 0.55),
                        confidence: 0.88
                    ),
                    indexTip: HandLandmarkPoint(
                        location: NormalizedPoint(x: 0.46, y: 0.56),
                        confidence: 0.91
                    ),
                    timestamp: 12
                )
            )
        )
        let detector = VisionHandLandmarkDetector(requestRunner: runner)
        var received: HandLandmarkObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 12))

        XCTAssertEqual(runner.callCount, 1)
        XCTAssertEqual(
            received,
            HandLandmarkObservation(
                thumbTip: HandLandmarkPoint(
                    location: NormalizedPoint(x: 0.40, y: 0.55),
                    confidence: 0.88
                ),
                indexTip: HandLandmarkPoint(
                    location: NormalizedPoint(x: 0.46, y: 0.56),
                    confidence: 0.91
                ),
                timestamp: 12
            )
        )
    }

    func testMissingThumbOrIndexProducesInvalidObservation() {
        let detector = VisionHandLandmarkDetector(
            requestRunner: StubHandLandmarkRequestRunner(
                result: .success(
                    HandLandmarkObservation(
                        thumbTip: nil,
                        indexTip: HandLandmarkPoint(
                            location: NormalizedPoint(x: 0.46, y: 0.56),
                            confidence: 0.91
                        ),
                        timestamp: 13
                    )
                )
            )
        )
        var received: HandLandmarkObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 13))

        XCTAssertEqual(received?.thumbTip, nil)
        XCTAssertEqual(
            received?.indexTip,
            HandLandmarkPoint(
                location: NormalizedPoint(x: 0.46, y: 0.56),
                confidence: 0.91
            )
        )
        XCTAssertEqual(received?.hasRequiredPinchLandmarks, false)
    }

    func testLowConfidenceLandmarkCanBeRejectedByRunner() {
        let detector = VisionHandLandmarkDetector(
            requestRunner: StubHandLandmarkRequestRunner(
                result: .success(
                    HandLandmarkObservation(
                        thumbTip: nil,
                        indexTip: HandLandmarkPoint(
                            location: NormalizedPoint(x: 0.46, y: 0.56),
                            confidence: 0.91
                        ),
                        timestamp: 14
                    )
                )
            )
        )
        var received: HandLandmarkObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 14))

        XCTAssertNil(received?.thumbTip)
        XCTAssertFalse(received?.hasRequiredPinchLandmarks ?? true)
    }

    func testStoppedDetectorIgnoresFrames() {
        let runner = StubHandLandmarkRequestRunner(
            result: .success(
                HandLandmarkObservation(
                    thumbTip: HandLandmarkPoint(
                        location: NormalizedPoint(x: 0.40, y: 0.55),
                        confidence: 0.88
                    ),
                    indexTip: HandLandmarkPoint(
                        location: NormalizedPoint(x: 0.46, y: 0.56),
                        confidence: 0.91
                    ),
                    timestamp: 15
                )
            )
        )
        let detector = VisionHandLandmarkDetector(requestRunner: runner)
        var observations: [HandLandmarkObservation] = []
        detector.onObservation = { observation in
            observations.append(observation)
        }

        detector.startDetection()
        detector.stopDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 15))

        XCTAssertEqual(runner.callCount, 0)
        XCTAssertTrue(observations.isEmpty)
    }

    func testRequestErrorEmitsFailure() {
        let detector = VisionHandLandmarkDetector(
            requestRunner: StubHandLandmarkRequestRunner(
                result: .failure(StubLandmarkError.requestFailed)
            )
        )
        var failure: String?
        detector.onFailure = { message in
            failure = message
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 15))

        XCTAssertEqual(failure, "Landmark request failed")
    }

    func testDefaultRunnerFailsClearlyWhenFrameHasNoSampleBuffer() {
        let detector = VisionHandLandmarkDetector()
        var failure: String?
        detector.onFailure = { message in
            failure = message
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 30))

        XCTAssertEqual(failure, "Camera frame sample buffer is unavailable")
    }
}

private final class StubHandLandmarkRequestRunner: HandLandmarkRequestRunning {
    private let result: Result<HandLandmarkObservation, Error>
    private(set) var callCount = 0

    init(result: Result<HandLandmarkObservation, Error>) {
        self.result = result
    }

    func landmarkObservation(in frame: CameraFrame) throws -> HandLandmarkObservation {
        callCount += 1
        return try result.get()
    }
}

private enum StubLandmarkError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Landmark request failed"
        }
    }
}
