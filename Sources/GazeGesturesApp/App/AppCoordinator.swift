import Foundation

final class AppCoordinator {
    let appState: AppState

    private let permissionProvider: PermissionProviding
    private let hotkeyManager: HotkeyManaging
    private let cameraSessionManager: CameraSessionManaging
    private let modeController: ModeController

    init(
        appState: AppState = AppState(),
        permissionProvider: PermissionProviding,
        hotkeyManager: HotkeyManaging,
        cameraSessionManager: CameraSessionManaging
    ) {
        self.appState = appState
        self.permissionProvider = permissionProvider
        self.hotkeyManager = hotkeyManager
        self.cameraSessionManager = cameraSessionManager
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
        cameraSessionManager.stopSession()
        hotkeyManager.stopListening()
    }

    func refreshPermissions() {
        modeController.refreshPermissions()
        appState.lastEventDescription = appState.permissions.summary
    }

    func requestCameraAccess() {
        appState.lastEventDescription = "Requesting Camera permission"

        permissionProvider.requestCameraAccess { [weak self] snapshot in
            self?.appState.permissions = snapshot
            self?.appState.lastEventDescription = snapshot.summary
        }
    }

    func requestAccessibilityTrust() {
        appState.permissions = permissionProvider.requestAccessibilityTrust()
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
            cameraSessionManager.stopSession()
            modeController.emergencyExit()
        }
    }

    private func handleCameraStateChange(_ state: CameraSessionState) {
        appState.cameraSessionState = state

        if case .failed(let message) = state {
            modeController.emergencyExit()
            appState.lastEventDescription = "Camera failed: \(message)"
        }
    }
}
