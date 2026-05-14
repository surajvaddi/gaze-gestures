import Foundation

final class AppCoordinator {
    let appState: AppState

    private let permissionProvider: PermissionProviding
    private let hotkeyManager: HotkeyManaging
    private let modeController: ModeController

    init(
        appState: AppState = AppState(),
        permissionProvider: PermissionProviding,
        hotkeyManager: HotkeyManaging
    ) {
        self.appState = appState
        self.permissionProvider = permissionProvider
        self.hotkeyManager = hotkeyManager
        self.modeController = ModeController(
            appState: appState,
            permissionProvider: permissionProvider
        )
    }

    func start() {
        modeController.refreshPermissions()

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
            modeController.activateGestureMode()
        case .emergencyExit:
            modeController.emergencyExit()
        }
    }
}
