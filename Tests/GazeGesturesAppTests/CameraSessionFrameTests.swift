import XCTest
@testable import GazeGesturesApp

final class CameraSessionFrameTests: XCTestCase {
    func testFakeCameraSessionPublishesFrameWhileActive() {
        let cameraSession = FramePublishingCameraSessionManager()
        var receivedTimestamps: [TimeInterval] = []
        cameraSession.onFrame = { frame in
            receivedTimestamps.append(frame.timestamp)
        }

        cameraSession.startSession()
        cameraSession.publishFrame(timestamp: 12.25)

        XCTAssertEqual(cameraSession.startCallCount, 1)
        XCTAssertEqual(receivedTimestamps, [12.25])
    }

    func testFakeCameraSessionDoesNotPublishFrameAfterStop() {
        let cameraSession = FramePublishingCameraSessionManager()
        var receivedTimestamps: [TimeInterval] = []
        cameraSession.onFrame = { frame in
            receivedTimestamps.append(frame.timestamp)
        }

        cameraSession.startSession()
        cameraSession.stopSession()
        cameraSession.publishFrame(timestamp: 12.25)

        XCTAssertEqual(cameraSession.stopCallCount, 1)
        XCTAssertTrue(receivedTimestamps.isEmpty)
    }
}

private final class FramePublishingCameraSessionManager: CameraSessionManaging {
    var onStateChange: ((CameraSessionState) -> Void)?
    var onFrame: ((CameraFrame) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private var isRunning = false

    func startSession() {
        startCallCount += 1
        isRunning = true
    }

    func stopSession() {
        stopCallCount += 1
        isRunning = false
    }

    func publishFrame(timestamp: TimeInterval) {
        guard isRunning else { return }

        onFrame?(
            CameraFrame(
                sampleBuffer: nil,
                timestamp: timestamp
            )
        )
    }
}
