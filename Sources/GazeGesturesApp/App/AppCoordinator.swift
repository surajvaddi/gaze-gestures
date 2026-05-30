import Foundation

final class AppCoordinator {
    let appState: AppState

    private let permissionProvider: PermissionProviding
    private let hotkeyManager: HotkeyManaging
    private let cameraSessionManager: CameraSessionManaging
    private let handPresenceDetector: HandPresenceDetecting
    private let handPresenceSessionController: HandPresenceSessionController
    private let modeController: ModeController
    private var isHandDetectionRunning = false

    init(
        appState: AppState = AppState(),
        permissionProvider: PermissionProviding,
        hotkeyManager: HotkeyManaging,
        cameraSessionManager: CameraSessionManaging,
        handPresenceDetector: HandPresenceDetecting = VisionHandPresenceDetector(),
        handPresenceSessionController: HandPresenceSessionController = HandPresenceSessionController()
    ) {
        self.appState = appState
        self.permissionProvider = permissionProvider
        self.hotkeyManager = hotkeyManager
        self.cameraSessionManager = cameraSessionManager
        self.handPresenceDetector = handPresenceDetector
        self.handPresenceSessionController = handPresenceSessionController
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
        stopHandDetection()
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
            stopHandDetection()
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
            stopHandDetection()
            modeController.emergencyExit()
            appState.lastEventDescription = "Camera failed: \(message)"
        case .idle, .stopping:
            stopHandDetection()
        case .starting, .running:
            break
        }
    }

    private func handleCameraFrame(_ frame: CameraFrame) {
        guard isHandDetectionRunning else { return }

        handPresenceDetector.process(frame)
    }

    private func handleHandPresenceObservation(_ observation: HandPresenceObservation) {
        guard isHandDetectionRunning,
              let stableObservation = handPresenceSessionController.process(observation) else {
            return
        }

        switch stableObservation.state {
        case .present where appState.mode == .armed:
            appState.mode = .handGesture
            appState.lastEventDescription = "Hand detected"
        case .absent where appState.mode == .handGesture:
            stopHandDetection()
            cameraSessionManager.stopSession()
            appState.mode = .idle
            appState.lastEventDescription = "Hand lost"
        case .failed(let message):
            stopHandDetection()
            cameraSessionManager.stopSession()
            appState.mode = .idle
            appState.lastEventDescription = "Hand detection failed: \(message)"
        case .unknown, .present, .absent:
            break
        }
    }

    private func handleRequiredPermissionLoss() {
        guard appState.mode.requiresActivePermissions,
              !appState.permissions.canEnterGestureMode else {
            return
        }

        stopHandDetection()
        cameraSessionManager.stopSession()
        appState.mode = .blocked
    }

    private func startHandDetection() {
        guard !isHandDetectionRunning else { return }

        isHandDetectionRunning = true
        handPresenceSessionController.reset()
        handPresenceDetector.startDetection()
    }

    private func stopHandDetection() {
        guard isHandDetectionRunning else { return }

        isHandDetectionRunning = false
        handPresenceSessionController.reset()
        handPresenceDetector.stopDetection()
    }
}
