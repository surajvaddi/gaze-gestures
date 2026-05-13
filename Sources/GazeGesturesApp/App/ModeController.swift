import Foundation

final class ModeController {
    private let appState: AppState
    private let permissionProvider: PermissionProviding

    init(
        appState: AppState,
        permissionProvider: PermissionProviding
    ) {
        self.appState = appState
        self.permissionProvider = permissionProvider
    }

    func refreshPermissions() {
        appState.permissions = permissionProvider.currentSnapshot()
    }

    func activateGestureMode() {
        let permissions = permissionProvider.currentSnapshot()
        appState.permissions = permissions

        guard permissions.canEnterGestureMode else {
            appState.mode = .blocked
            appState.lastEventDescription = permissions.summary
            return
        }

        guard appState.mode != .armed else {
            appState.lastEventDescription = "Already armed"
            return
        }

        appState.mode = .armed
        appState.lastEventDescription = "Activation hotkey accepted"
    }

    func emergencyExit() {
        appState.mode = .idle
        appState.lastEventDescription = "Emergency exit"
    }
}
