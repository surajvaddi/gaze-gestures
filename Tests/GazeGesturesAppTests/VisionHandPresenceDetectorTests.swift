import XCTest
@testable import GazeGesturesApp

final class VisionHandPresenceDetectorTests: XCTestCase {
    func testSuccessfulVisionResultWithHandEmitsPresent() {
        let detector = VisionHandPresenceDetector(
            requestRunner: StubHandPresenceRequestRunner(result: .success(1))
        )
        var received: HandPresenceObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 10))

        XCTAssertEqual(
            received,
            HandPresenceObservation(
                state: .present,
                confidence: 1,
                timestamp: 10
            )
        )
    }

    func testSuccessfulVisionResultWithNoHandsEmitsAbsent() {
        let detector = VisionHandPresenceDetector(
            requestRunner: StubHandPresenceRequestRunner(result: .success(0))
        )
        var received: HandPresenceObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 11))

        XCTAssertEqual(
            received,
            HandPresenceObservation(
                state: .absent,
                confidence: 1,
                timestamp: 11
            )
        )
    }

    func testVisionErrorEmitsFailure() {
        let detector = VisionHandPresenceDetector(
            requestRunner: StubHandPresenceRequestRunner(result: .failure(StubVisionError.requestFailed))
        )
        var received: HandPresenceObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 12))

        XCTAssertEqual(
            received,
            HandPresenceObservation(
                state: .failed("Vision request failed"),
                confidence: 0,
                timestamp: 12
            )
        )
    }

    func testStoppedDetectorIgnoresFrames() {
        let runner = StubHandPresenceRequestRunner(result: .success(1))
        let detector = VisionHandPresenceDetector(requestRunner: runner)
        var receivedObservations: [HandPresenceObservation] = []
        detector.onObservation = { observation in
            receivedObservations.append(observation)
        }

        detector.startDetection()
        detector.stopDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 13))

        XCTAssertEqual(runner.callCount, 0)
        XCTAssertTrue(receivedObservations.isEmpty)
    }

    func testDefaultVisionRunnerFailsClearlyWhenFrameHasNoSampleBuffer() {
        let detector = VisionHandPresenceDetector()
        var received: HandPresenceObservation?
        detector.onObservation = { observation in
            received = observation
        }

        detector.startDetection()
        detector.process(CameraFrame(sampleBuffer: nil, timestamp: 14))

        XCTAssertEqual(
            received,
            HandPresenceObservation(
                state: .failed("Camera frame sample buffer is unavailable"),
                confidence: 0,
                timestamp: 14
            )
        )
    }
}

private final class StubHandPresenceRequestRunner: HandPresenceRequestRunning {
    private let result: Result<Int, Error>
    private(set) var callCount = 0

    init(result: Result<Int, Error>) {
        self.result = result
    }

    func detectedHandCount(in frame: CameraFrame) throws -> Int {
        callCount += 1
        return try result.get()
    }
}

private enum StubVisionError: LocalizedError {
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "Vision request failed"
        }
    }
}
