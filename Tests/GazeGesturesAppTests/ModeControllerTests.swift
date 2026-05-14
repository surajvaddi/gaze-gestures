import XCTest
@testable import GazeGesturesApp

final class ModeControllerTests: XCTestCase {
    func testActivationBlocksWhenPermissionsAreMissing() {
        let appState = AppState()
        let provider = StubPermissionProvider(snapshot: .unknown)
        let controller = ModeController(appState: appState, permissionProvider: provider)

        let result = controller.activateGestureMode()

        XCTAssertEqual(result, .blocked)
        XCTAssertEqual(appState.mode, .blocked)
        XCTAssertEqual(appState.permissions.camera, .unknown)
        XCTAssertEqual(appState.permissions.accessibility, .unknown)
        XCTAssertEqual(appState.lastEventDescription, "Missing: Camera unknown, Accessibility unknown")
    }

    func testActivationArmsWhenPermissionsAreGranted() {
        let appState = AppState()
        let provider = StubPermissionProvider(
            snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let controller = ModeController(appState: appState, permissionProvider: provider)

        let result = controller.activateGestureMode()

        XCTAssertEqual(result, .armed)
        XCTAssertEqual(appState.mode, .armed)
        XCTAssertEqual(appState.lastEventDescription, "Activation hotkey accepted")
    }

    func testEmergencyExitReturnsToIdle() {
        let appState = AppState()
        let provider = StubPermissionProvider(
            snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let controller = ModeController(appState: appState, permissionProvider: provider)

        controller.activateGestureMode()
        XCTAssertEqual(controller.activateGestureMode(), .alreadyArmed)
        controller.emergencyExit()

        XCTAssertEqual(appState.mode, .idle)
        XCTAssertEqual(appState.lastEventDescription, "Emergency exit")
    }
}

private final class StubPermissionProvider: PermissionProviding {
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
