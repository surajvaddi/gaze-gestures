import XCTest
@testable import GazeGesturesApp

final class PermissionSnapshotTests: XCTestCase {
    func testUnknownSnapshotCannotEnterGestureMode() {
        let snapshot = PermissionSnapshot.unknown

        XCTAssertFalse(snapshot.canEnterGestureMode)
        XCTAssertEqual(snapshot.missingRequiredPermissions, [.camera, .accessibility])
        XCTAssertEqual(snapshot.missingPermissionNames, "Camera + Accessibility")
        XCTAssertEqual(snapshot.permissionCallout, "Needs Camera + Accessibility")
    }

    func testGrantedSnapshotCanEnterGestureMode() {
        let snapshot = PermissionSnapshot(
            camera: .granted,
            accessibility: .granted
        )

        XCTAssertTrue(snapshot.canEnterGestureMode)
        XCTAssertTrue(snapshot.missingRequiredPermissions.isEmpty)
        XCTAssertEqual(snapshot.summary, "Required permissions granted")
        XCTAssertEqual(snapshot.permissionCallout, "Camera and Accessibility granted")
    }

    func testSummaryIncludesSpecificMissingStatuses() {
        let snapshot = PermissionSnapshot(
            camera: .denied,
            accessibility: .restricted
        )

        XCTAssertEqual(snapshot.summary, "Missing: Camera denied, Accessibility restricted")
    }
}
