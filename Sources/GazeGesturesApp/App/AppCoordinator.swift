import Foundation

final class AppCoordinator {
    let appState: AppState

    private let permissionProvider: PermissionProviding
    private let hotkeyManager: HotkeyManaging
    private let cameraSessionManager: CameraSessionManaging
    private let handPresenceDetector: HandPresenceDetecting
    private let handPresenceSessionController: HandPresenceSessionController
    private let handLandmarkDetector: HandLandmarkDetecting
    private let pinchDistanceClassifier: PinchDistanceClassifier
    private let pinchObservationBuffer: PinchObservationBuffer
    private let temporalPinchClassifier: TemporalPinchClassifier
    private let pinchCooldownController: PinchCooldownController
    private let pinchStabilityController: PinchStabilityController
    private let pinchCursorMapper: PinchCursorMapper
    private let pinchCursorSmoother: PinchCursorSmoother
    private let screenBoundsProvider: ScreenBoundsProviding
    private let modeController: ModeController
    private var isHandDetectionRunning = false
    private var isHandLandmarkDetectionRunning = false

    init(
        appState: AppState = AppState(),
        permissionProvider: PermissionProviding,
        hotkeyManager: HotkeyManaging,
        cameraSessionManager: CameraSessionManaging,
        handPresenceDetector: HandPresenceDetecting = VisionHandPresenceDetector(),
        handPresenceSessionController: HandPresenceSessionController = HandPresenceSessionController(),
        handLandmarkDetector: HandLandmarkDetecting = VisionHandLandmarkDetector(),
        pinchDistanceClassifier: PinchDistanceClassifier = PinchDistanceClassifier(),
        pinchObservationBuffer: PinchObservationBuffer = PinchObservationBuffer(),
        temporalPinchClassifier: TemporalPinchClassifier = TemporalPinchClassifier(),
        pinchCooldownController: PinchCooldownController = PinchCooldownController(),
        pinchStabilityController: PinchStabilityController = PinchStabilityController(),
        pinchCursorMapper: PinchCursorMapper = PinchCursorMapper(),
        pinchCursorSmoother: PinchCursorSmoother = PinchCursorSmoother(),
        screenBoundsProvider: ScreenBoundsProviding = AppKitScreenBoundsProvider()
    ) {
        self.appState = appState
        self.permissionProvider = permissionProvider
        self.hotkeyManager = hotkeyManager
        self.cameraSessionManager = cameraSessionManager
        self.handPresenceDetector = handPresenceDetector
        self.handPresenceSessionController = handPresenceSessionController
        self.handLandmarkDetector = handLandmarkDetector
        self.pinchDistanceClassifier = pinchDistanceClassifier
        self.pinchObservationBuffer = pinchObservationBuffer
        self.temporalPinchClassifier = temporalPinchClassifier
        self.pinchCooldownController = pinchCooldownController
        self.pinchStabilityController = pinchStabilityController
        self.pinchCursorMapper = pinchCursorMapper
        self.pinchCursorSmoother = pinchCursorSmoother
        self.screenBoundsProvider = screenBoundsProvider
        self.modeController = ModeController(
            appState: appState,
            permissionProvider: permissionProvider
        )
    }

    func start() {
        modeController.refreshPermissions()

        cameraSessionManager.onStateChange = { [weak self] state in
            self?.handleCameraStateChange(state)
        }

        cameraSessionManager.onFrame = { [weak self] frame in
            self?.handleCameraFrame(frame)
        }

        handPresenceDetector.onObservation = { [weak self] observation in
            self?.handleHandPresenceObservation(observation)
        }

        handLandmarkDetector.onObservation = { [weak self] observation in
            self?.handleHandLandmarkObservation(observation)
        }

        handLandmarkDetector.onFailure = { [weak self] message in
            self?.handleHandLandmarkFailure(message)
        }

        hotkeyManager.onHotkey = { [weak self] hotkey in
            self?.handleHotkey(hotkey)
        }

        switch hotkeyManager.startListening() {
        case .success:
            break
        case .failure(let failure):
            appState.lastEventDescription = failure.userMessage
        }
    }

    func stop() {
        stopHandLandmarkDetection()
        stopHandDetection()
        appState.handDetectionState = .idle
        cameraSessionManager.stopSession()
        hotkeyManager.stopListening()
    }

    func refreshPermissions() {
        modeController.refreshPermissions()
        handleRequiredPermissionLoss()
        appState.lastEventDescription = appState.permissions.summary
    }

    func requestCameraAccess() {
        appState.lastEventDescription = "Requesting Camera permission"

        permissionProvider.requestCameraAccess { [weak self] snapshot in
            guard let self else { return }

            self.appState.permissions = snapshot
            self.handleRequiredPermissionLoss()
            self.appState.lastEventDescription = snapshot.summary
        }
    }

    func requestAccessibilityTrust() {
        appState.permissions = permissionProvider.requestAccessibilityTrust()
        handleRequiredPermissionLoss()
        appState.lastEventDescription = appState.permissions.summary
    }

    func openSystemSettings(for kind: PermissionKind) {
        permissionProvider.openSystemSettings(for: kind)
    }

    private func handleHotkey(_ hotkey: GlobalHotkey) {
        switch hotkey {
        case .activateGestureMode:
            let result = modeController.activateGestureMode()
            if result == .armed || result == .alreadyArmed {
                cameraSessionManager.startSession()
            }
        case .emergencyExit:
            stopHandLandmarkDetection()
            stopHandDetection()
            appState.handDetectionState = .idle
            cameraSessionManager.stopSession()
            modeController.emergencyExit()
        }
    }

    private func handleCameraStateChange(_ state: CameraSessionState) {
        appState.cameraSessionState = state

        switch state {
        case .running where appState.mode == .armed:
            startHandDetection()
        case .failed(let message):
            stopHandLandmarkDetection()
            stopHandDetection()
            modeController.emergencyExit()
            appState.handDetectionState = .idle
            appState.lastEventDescription = "Camera failed: \(message)"
        case .idle, .stopping:
            stopHandLandmarkDetection()
            stopHandDetection()
            appState.handDetectionState = .idle
        case .starting, .running:
            break
        }
    }

    private func handleCameraFrame(_ frame: CameraFrame) {
        if isHandDetectionRunning {
            handPresenceDetector.process(frame)
        }

        if isHandLandmarkDetectionRunning {
            handLandmarkDetector.process(frame)
        }
    }

    private func handleHandPresenceObservation(_ observation: HandPresenceObservation) {
        guard isHandDetectionRunning,
              let stableObservation = handPresenceSessionController.process(observation) else {
            return
        }

        switch stableObservation.state {
        case .present where appState.mode == .armed:
            appState.mode = .handGesture
            appState.handDetectionState = .detected
            appState.lastEventDescription = "Hand detected"
            startHandLandmarkDetection()
        case .absent where appState.mode == .handGesture:
            stopHandLandmarkDetection()
            stopHandDetection()
            cameraSessionManager.stopSession()
            appState.mode = .idle
            appState.handDetectionState = .lost
            appState.lastEventDescription = "Hand lost"
        case .failed(let message):
            stopHandLandmarkDetection()
            stopHandDetection()
            cameraSessionManager.stopSession()
            appState.mode = .idle
            appState.handDetectionState = .failed(message)
            appState.lastEventDescription = "Hand detection failed: \(message)"
        case .unknown, .present, .absent:
            break
        }
    }

    private func handleHandLandmarkObservation(_ observation: HandLandmarkObservation) {
        guard isHandLandmarkDetectionRunning,
              appState.mode == .handGesture else {
            return
        }

        pinchObservationBuffer.append(pinchDistanceClassifier.classify(observation))

        switch temporalPinchClassifier.evaluate(pinchObservationBuffer.allObservations()) {
        case .accepted(let stableObservation):
            handleAcceptedPinchObservation(stableObservation)
        case .rejected:
            break
        }
    }

    private func handleAcceptedPinchObservation(_ stableObservation: PinchObservation) {
        switch stableObservation.state {
        case .pinching:
            guard pinchCooldownController.allowsActivation(at: stableObservation.timestamp) else {
                hidePinchCursor()
                return
            }

            guard let bounds = screenBoundsProvider.currentScreenBounds(),
                  let mappedPoint = pinchCursorMapper.map(stableObservation, in: bounds) else {
                hidePinchCursor()
                return
            }

            appState.virtualCursorState = .visible(
                pinchCursorSmoother.smooth(mappedPoint)
            )
            appState.lastEventDescription = "Pinch cursor active"
        case .open:
            pinchCooldownController.registerRelease(at: stableObservation.timestamp)
            pinchObservationBuffer.reset()
            hidePinchCursor()
            appState.lastEventDescription = "Pinch released"
        case .unknown:
            break
        }
    }

    private func handleHandLandmarkFailure(_ message: String) {
        stopHandLandmarkDetection()
        stopHandDetection()
        cameraSessionManager.stopSession()
        appState.mode = .idle
        appState.handDetectionState = .failed(message)
        appState.lastEventDescription = "Hand landmark detection failed: \(message)"
    }

    private func handleRequiredPermissionLoss() {
        guard appState.mode.requiresActivePermissions,
              !appState.permissions.canEnterGestureMode else {
            return
        }

        stopHandLandmarkDetection()
        stopHandDetection()
        appState.handDetectionState = .idle
        cameraSessionManager.stopSession()
        appState.mode = .blocked
    }

    private func startHandDetection() {
        guard !isHandDetectionRunning else { return }

        isHandDetectionRunning = true
        handPresenceSessionController.reset()
        appState.handDetectionState = .looking
        handPresenceDetector.startDetection()
    }

    private func stopHandDetection() {
        guard isHandDetectionRunning else { return }

        isHandDetectionRunning = false
        handPresenceSessionController.reset()
        handPresenceDetector.stopDetection()
    }

    private func startHandLandmarkDetection() {
        guard !isHandLandmarkDetectionRunning else { return }

        isHandLandmarkDetectionRunning = true
        resetPinchPipelineState()
        handLandmarkDetector.startDetection()
    }

    private func stopHandLandmarkDetection() {
        guard isHandLandmarkDetectionRunning else {
            resetPinchPipelineState()
            return
        }

        isHandLandmarkDetectionRunning = false
        handLandmarkDetector.stopDetection()
        resetPinchPipelineState()
    }

    private func resetPinchPipelineState() {
        pinchStabilityController.reset()
        pinchObservationBuffer.reset()
        pinchCooldownController.reset()
        pinchCursorSmoother.reset()
        appState.virtualCursorState = .hidden
    }

    private func hidePinchCursor() {
        pinchCursorSmoother.reset()
        appState.virtualCursorState = .hidden
    }
}
