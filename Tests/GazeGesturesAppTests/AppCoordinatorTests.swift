import XCTest
@testable import GazeGesturesApp

final class AppCoordinatorTests: XCTestCase {
    func testStartRefreshesPermissionsAndStartsHotkeys() {
        let permissionProvider = CoordinatorPermissionProvider(
            snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let hotkeyManager = CoordinatorHotkeyManager()
        let coordinator = AppCoordinator(
            permissionProvider: permissionProvider,
            hotkeyManager: hotkeyManager
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
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(snapshot: .unknown),
            hotkeyManager: hotkeyManager
        )

        coordinator.start()

        XCTAssertEqual(coordinator.appState.lastEventDescription, "Activation hotkey unavailable (-9878)")
    }

    func testActivationHotkeyRoutesThroughModeController() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)

        XCTAssertEqual(coordinator.appState.mode, .armed)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Activation hotkey accepted")
    }

    func testEmergencyExitHotkeyRoutesThroughModeController() {
        let hotkeyManager = CoordinatorHotkeyManager()
        let coordinator = AppCoordinator(
            permissionProvider: CoordinatorPermissionProvider(
                snapshot: PermissionSnapshot(camera: .granted, accessibility: .granted)
            ),
            hotkeyManager: hotkeyManager
        )

        coordinator.start()
        hotkeyManager.fire(.activateGestureMode)
        hotkeyManager.fire(.emergencyExit)

        XCTAssertEqual(coordinator.appState.mode, .idle)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Emergency exit")
    }

    func testPermissionActionsUpdateState() {
        let permissionProvider = CoordinatorPermissionProvider(snapshot: .unknown)
        let coordinator = AppCoordinator(
            permissionProvider: permissionProvider,
            hotkeyManager: CoordinatorHotkeyManager()
        )

        permissionProvider.snapshot = PermissionSnapshot(camera: .granted, accessibility: .restricted)
        coordinator.refreshPermissions()

        XCTAssertEqual(coordinator.appState.permissions.camera, .granted)
        XCTAssertEqual(coordinator.appState.permissions.accessibility, .restricted)
        XCTAssertEqual(coordinator.appState.lastEventDescription, "Missing: Accessibility restricted")
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
