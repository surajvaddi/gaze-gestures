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

    @discardableResult
    func activateGestureMode() -> ActivationResult {
        let permissions = permissionProvider.currentSnapshot()
        appState.permissions = permissions

        guard permissions.canEnterGestureMode else {
            appState.mode = .blocked
            appState.lastEventDescription = permissions.summary
            return .blocked
        }

        guard appState.mode != .armed else {
            appState.lastEventDescription = "Already armed"
            return .alreadyArmed
        }

        appState.mode = .armed
        appState.lastEventDescription = "Activation hotkey accepted"
        return .armed
    }

    func emergencyExit() {
        appState.mode = .idle
        appState.lastEventDescription = "Emergency exit"
    }
}

enum ActivationResult: Equatable {
    case blocked
    case armed
    case alreadyArmed
}
