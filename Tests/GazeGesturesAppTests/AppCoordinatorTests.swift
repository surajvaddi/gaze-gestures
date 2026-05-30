import XCTest
@testable import GazeGesturesApp

final class AppCoordinatorTests: XCTestCase {
    func testStartRefreshesPermissionsAndStartsHotkeys() {
        let permissionProvider = CoordinatorPermissionProvider(
            snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: permissionProvider,
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()

        XCTAssertTrue(hotkeyManager.didStartListening)
        XCTAssertEqual(coordinator.appState.permissions.camera, .granted)
        XCTAssertEqual(coordinator.appState.permissions.accessibility, .granted)
    }

    func testStartSurfacesHotkeyRegistrationFailure() {
        let hotkeyManager = CoordinatorHotkeyManager(
            startResult: .failure(.activationHotkeyFailed(-9878))
        )
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(snapshot: .unknown),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()

        XCTAssertEqual(coordinator.appState.lastEventDescription, "Activation hotkey unavailable (-9878)")
    }

    func testActivationHotkeyRoutesThroughModeController() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)

        XCTAssertEqual(coordinator.appState.mode, .armed)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Activation hotkey accepted")
        XCTAssertEqual(cameraSessionManager.startCallCount, 1)
    }

    func testEmergencyExitHotkeyRoutesThroughModeController() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)
        hotkeyManager.fire(.emergencyExit)

        XCTAssertEqual(coordinator.appState.mode, .idle)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Emergency exit")
        XCTAssertEqual(cameraSessionManager.stopCallCount, 1)
    }

    func testBlockedActivationDoesNotStartCamera() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(snapshot: .unknown),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)

        XCTAssertEqual(coordinator.appState.mode, .blocked)
        XCTAssertEqual(cameraSessionManager.startCallCount, 0)
    }

    func testCameraStateChangesUpdateAppState() {
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: CoordinatorHotkeyManager(),
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()
        cameraSessionManager.publish(.running)

        XCTAssertEqual(coordinator.appState.cameraSessionState, .running)
    }

    func testCameraRunningWhileArmedStartsHandDetection() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let handPresenceDetector = CoordinatorHandPresenceDetector()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager,
            handPresenceDetector: handPresenceDetector
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)
        cameraSessionManager.publish(.running)
        cameraSessionManager.publish(.running)

        XCTAssertEqual(handPresenceDetector.startCallCount, 1)
        XCTAssertTrue(handPresenceDetector.isRunning)
    }

    func testCameraRunningWhileIdleDoesNotStartHandDetection() {
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let handPresenceDetector = CoordinatorHandPresenceDetector()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: CoordinatorHotkeyManager(),
            cameraSessionManager: cameraSessionManager,
            handPresenceDetector: handPresenceDetector
        )

        coordinator.start()
        cameraSessionManager.publish(.running)

        XCTAssertEqual(coordinator.appState.mode, .idle)
        XCTAssertEqual(handPresenceDetector.startCallCount, 0)
    }

    func testCameraFramesForwardOnlyAfterHandDetectionStarts() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let handPresenceDetector = CoordinatorHandPresenceDetector()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager,
            handPresenceDetector: handPresenceDetector
        )

        coordinator.start()
        cameraSessionManager.publishFrame(timestamp: 1)
        hotkeyManager.fire(.activateGestureMode)
        cameraSessionManager.publishFrame(timestamp: 2)
        cameraSessionManager.publish(.running)
        cameraSessionManager.publishFrame(timestamp: 3)

        XCTAssertEqual(handPresenceDetector.processedFrameTimestamps, [3])
    }

    func testCameraFailureReturnsToIdleAndSurfacesMessage() {
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let handPresenceDetector = CoordinatorHandPresenceDetector()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: CoordinatorHotkeyManager(),
            cameraSessionManager: cameraSessionManager,
            handPresenceDetector: handPresenceDetector
        )

        coordinator.start()
        coordinator.appState.mode = .armed
        cameraSessionManager.publish(.running)
        cameraSessionManager.publish(.failed("No video camera is available"))

        XCTAssertEqual(coordinator.appState.mode, .idle)
        XCTAssertEqual(coordinator.appState.cameraSessionState, .failed("No video camera is available"))
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Camera failed: No video camera is available")
        XCTAssertEqual(handPresenceDetector.stopCallCount, 1)
    }

    func testPermissionActionsUpdateState() {
        let permissionProvider = CoordinatorPermissionProvider(snapshot: .unknown)
        let coordinator = AppCoordinator(
            permissionProvider: permissionProvider,
            hotkeyManager: CoordinatorHotkeyManager(),
            cameraSessionManager: CoordinatorCameraSessionManager()
        )

        permissionProvider.snapshot = PermissionSnapshot(camera: .granted, accessibility: .restricted)
        coordinator.refreshPermissions()

        XCTAssertEqual(coordinator.appState.permissions.camera, .granted)
        XCTAssertEqual(coordinator.appState.permissions.accessibility, .restricted)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Missing: Accessibility restricted")
    }

    func testPermissionRefreshStopsCameraAndBlocksWhenActivePermissionsAreLost() {
        let permissionProvider = CoordinatorPermissionProvider(
            snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: permissionProvider,
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)

        permissionProvider.snapshot = PermissionSnapshot(camera: .denied, accessibility: .granted)
        coordinator.refreshPermissions()

        XCTAssertEqual(coordinator.appState.mode, .blocked)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Missing: Camera denied")
        XCTAssertEqual(cameraSessionManager.stopCallCount, 1)
    }

    func testCameraPermissionRequestStopsCameraWhenActivePermissionIsDenied() {
        let permissionProvider = CoordinatorPermissionProvider(
            snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let coordinator = AppCoordinator(
            permissionProvider: permissionProvider,
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)

        permissionProvider.snapshot = PermissionSnapshot(camera: .denied, accessibility: .granted)
        coordinator.requestCameraAccess()

        XCTAssertEqual(coordinator.appState.mode, .blocked)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Missing: Camera denied")
        XCTAssertEqual(cameraSessionManager.stopCallCount, 1)
    }

    func testStopStopsHotkeysAndCamera() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let handPresenceDetector = CoordinatorHandPresenceDetector()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(snapshot: .unknown),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager,
            handPresenceDetector: handPresenceDetector
        )

        coordinator.start()
        coordinator.appState.mode = .armed
        cameraSessionManager.publish(.running)
        coordinator.stop()

        XCTAssertTrue(hotkeyManager.didStopListening)
        XCTAssertEqual(cameraSessionManager.stopCallCount, 1)
        XCTAssertEqual(handPresenceDetector.stopCallCount, 1)
    }

    func testEmergencyExitStopsHandDetection() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let cameraSessionManager = CoordinatorCameraSessionManager()
        let handPresenceDetector = CoordinatorHandPresenceDetector()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager,
            cameraSessionManager: cameraSessionManager,
            handPresenceDetector: handPresenceDetector
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)
        cameraSessionManager.publish(.running)
        hotkeyManager.fire(.emergencyExit)

        XCTAssertEqual(handPresenceDetector.stopCallCount, 1)
        XCTAssertFalse(handPresenceDetector.isRunning)
    }
}

private final class CoordinatorHotkeyManager: HotkeyManaging {
    var onHotkey: ((GlobalHotkey) -> Void)?
    var didStartListening = false
    var didStopListening = false

    private let startResult: Result<Void, HotkeyRegistrationFailure>

    init(startResult: Result<Void, HotkeyRegistrationFailure> = .success(())) {
        self.startResult = startResult
    }

    func startListening() -> Result<Void, HotkeyRegistrationFailure> {
        didStartListening = true
        return startResult
    }

    func stopListening() {
        didStopListening = true
    }

    func fire(_ hotkey: GlobalHotkey) {
        onHotkey?(hotkey)
    }
}

private final class CoordinatorPermissionProvider: PermissionProviding {
    var snapshot: PermissionSnapshot

    init(snapshot: PermissionSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> PermissionSnapshot {
        snapshot
    }

    func requestCameraAccess(completion: @escaping (PermissionSnapshot) -> Void) {
        completion(snapshot)
    }

    func requestAccessibilityTrust() -> PermissionSnapshot {
        snapshot
    }

    func openSystemSettings(for kind: PermissionKind) {}
}

private final class CoordinatorCameraSessionManager: CameraSessionManaging {
    var onStateChange: ((CameraSessionState) -> Void)?
    var onFrame: ((CameraFrame) -> Void)?
    var startCallCount = 0
    var stopCallCount = 0

    func startSession() {
        startCallCount += 1
    }

    func stopSession() {
        stopCallCount += 1
    }

    func publish(_ state: CameraSessionState) {
        onStateChange?(state)
    }

    func publishFrame(timestamp: TimeInterval) {
        onFrame?(
            CameraFrame(
                sampleBuffer: nil,
                timestamp: timestamp
            )
        )
    }
}

private final class CoordinatorHandPresenceDetector: HandPresenceDetecting {
    var onObservation: ((HandPresenceObservation) -> Void)?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var processedFrameTimestamps: [TimeInterval] = []
    private(set) var isRunning = false

    func startDetection() {
        startCallCount += 1
        isRunning = true
    }

    func stopDetection() {
        stopCallCount += 1
        isRunning = false
    }

    func process(_ frame: CameraFrame) {
        guard isRunning else { return }

        processedFrameTimestamps.append(frame.timestamp)
    }
}
