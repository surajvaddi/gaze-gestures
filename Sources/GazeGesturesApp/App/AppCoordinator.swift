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
    private let handScrollPointMapper: PinchCursorMapper
    private let pinchCursorSmoother: PinchCursorSmoother
    private let safeClickGate: SafeClickGate
    private let clickCooldownController: ClickCooldownController
    private let pinchClickIntentTracker: PinchClickIntentTracker
    private let pinchDragIntentTracker: PinchDragIntentTracker
    private let handScrollIntentDetector: HandScrollIntentDetector
    private let clickDispatcher: ClickDispatching
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
        handScrollPointMapper: PinchCursorMapper = PinchCursorMapper(
            configuration: PinchCursorMappingConfiguration(
                minimumConfidence: 0.65,
                mirrorsHorizontally: false,
                invertsVertically: false,
                requiredState: .open
            )
        ),
        pinchCursorSmoother: PinchCursorSmoother = PinchCursorSmoother(),
        safeClickGate: SafeClickGate = SafeClickGate(),
        clickCooldownController: ClickCooldownController = ClickCooldownController(),
        pinchClickIntentTracker: PinchClickIntentTracker = PinchClickIntentTracker(),
        pinchDragIntentTracker: PinchDragIntentTracker = PinchDragIntentTracker(),
        handScrollIntentDetector: HandScrollIntentDetector = HandScrollIntentDetector(),
        clickDispatcher: ClickDispatching = CGEventClickDispatcher(),
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
        self.handScrollPointMapper = handScrollPointMapper
        self.pinchCursorSmoother = pinchCursorSmoother
        self.safeClickGate = safeClickGate
        self.clickCooldownController = clickCooldownController
        self.pinchClickIntentTracker = pinchClickIntentTracker
        self.pinchDragIntentTracker = pinchDragIntentTracker
        self.handScrollIntentDetector = handScrollIntentDetector
        self.clickDispatcher = clickDispatcher
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
        let clickIntent = pinchClickIntentTracker.process(stableObservation)

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

            let smoothedPoint = pinchCursorSmoother.smooth(mappedPoint)
            appState.virtualCursorState = .visible(smoothedPoint)

            let dragIntent = pinchDragIntentTracker.process(
                observation: stableObservation,
                cursorPoint: smoothedPoint
            )
            if !handlePinchDragIntent(dragIntent) {
                appState.lastEventDescription = "Pinch cursor active"
            }
        case .open:
            let dragIntent = pinchDragIntentTracker.process(
                observation: stableObservation,
                cursorPoint: nil
            )
            let handledDragOutcome = handlePinchDragIntent(dragIntent)
            let handledClickOutcome = handledDragOutcome
                || handlePinchClickIntent(clickIntent, for: stableObservation)
            let handledScrollOutcome = handledClickOutcome
                ? false
                : handleHandScrollObservation(stableObservation)
            pinchCooldownController.registerRelease(at: stableObservation.timestamp)
            pinchObservationBuffer.reset()
            hidePinchCursor()
            if !handledClickOutcome && !handledScrollOutcome {
                appState.lastEventDescription = "Pinch released"
            }
        case .unknown:
            break
        }
    }

    private func handleHandScrollObservation(_ stableObservation: PinchObservation) -> Bool {
        guard let bounds = screenBoundsProvider.currentScreenBounds(),
              let scrollPoint = handScrollPointMapper.map(stableObservation, in: bounds) else {
            _ = handScrollIntentDetector.process(point: nil)
            return false
        }

        switch handScrollIntentDetector.process(point: scrollPoint) {
        case .none:
            return false
        case .scrolled(let delta):
            switch clickDispatcher.dispatchScroll(delta) {
            case .success:
                appState.lastEventDescription = "Scrolled"
            case .failure:
                appState.lastEventDescription = "Scroll failed"
            }
            return true
        }
    }

    private func handlePinchDragIntent(_ intent: PinchDragIntent) -> Bool {
        switch intent {
        case .none:
            return false
        case .started(let point):
            switch clickDispatcher.dispatchLeftMouseDown(at: point) {
            case .success:
                appState.lastEventDescription = "Drag started"
            case .failure:
                appState.lastEventDescription = "Drag failed"
            }
            return true
        case .moved(let point):
            switch clickDispatcher.dispatchLeftMouseDrag(to: point) {
            case .success:
                appState.lastEventDescription = "Dragging"
            case .failure:
                appState.lastEventDescription = "Drag failed"
            }
            return true
        case .ended(let point):
            switch clickDispatcher.dispatchLeftMouseUp(at: point) {
            case .success:
                appState.lastEventDescription = "Drag ended"
            case .failure:
                appState.lastEventDescription = "Drag failed"
            }
            return true
        case .cancelled:
            appState.lastEventDescription = "Drag cancelled"
            return true
        }
    }

    private func handlePinchClickIntent(
        _ intent: PinchClickIntent,
        for stableObservation: PinchObservation
    ) -> Bool {
        guard case .releaseCompleted = intent else {
            return false
        }

        let decision = safeClickGate.evaluate(
            SafeClickGateRequest(
                mode: appState.mode,
                virtualCursorState: appState.virtualCursorState,
                confidence: stableObservation.confidence,
                isReleaseIntent: true,
                allowsClick: pinchCooldownController.allowsActivation(at: stableObservation.timestamp)
                    && clickCooldownController.allowsClick(at: stableObservation.timestamp)
            )
        )

        guard case .accepted(let point) = decision else {
            if case .rejected(let reason) = decision {
                appState.lastEventDescription = "Pinch click blocked: \(reason.userMessage)"
            }
            return true
        }

        switch clickDispatcher.dispatchLeftClick(at: point) {
        case .success:
            clickCooldownController.registerClick(at: stableObservation.timestamp)
            appState.lastEventDescription = "Pinch click dispatched"
        case .failure:
            appState.lastEventDescription = "Pinch click failed"
        }

        return true
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
        clickCooldownController.reset()
        pinchClickIntentTracker.reset()
        pinchDragIntentTracker.reset()
        handScrollIntentDetector.reset()
        pinchCursorSmoother.reset()
        appState.virtualCursorState = .hidden
    }

    private func hidePinchCursor() {
        pinchCursorSmoother.reset()
        appState.virtualCursorState = .hidden
    }
}
