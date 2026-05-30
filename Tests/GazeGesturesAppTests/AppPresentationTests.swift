import XCTest
@testable import GazeGesturesApp

final class AppPresentationTests: XCTestCase {
    func testModePresentationCoversCurrentAndFutureModes() {
        let permissions = PermissionSnapshot(camera: .granted, accessibility: .granted)

        XCTAssertEqual(
            AppPresentation.mode(for: .idle, permissions: permissions),
            ModePresentation(
                label: "Idle: Off",
                helpText: "Gesture control is off. Press Control-Option-Command-Space to request activation.",
                tint: .gray
            )
        )
        XCTAssertEqual(AppPresentation.mode(for: .blocked, permissions: .unknown).tint, .orange)
        XCTAssertEqual(AppPresentation.mode(for: .armed, permissions: permissions).label, "Armed: Ready")
        XCTAssertEqual(AppPresentation.mode(for: .handGesture, permissions: permissions).label, "Hand: Active")
        XCTAssertEqual(AppPresentation.mode(for: .gazeGesture, permissions: permissions).tint, .purple)
        XCTAssertEqual(AppPresentation.mode(for: .suspended, permissions: permissions).tint, .blue)
        XCTAssertEqual(AppPresentation.mode(for: .emergencyExiting, permissions: permissions).tint, .red)
    }

    func testBlockedModeHelpIncludesPermissionSummary() {
        let presentation = AppPresentation.mode(
            for: .blocked,
            permissions: PermissionSnapshot(camera: .denied, accessibility: .unknown)
        )

        XCTAssertEqual(
            presentation.helpText,
            "Missing: Camera denied, Accessibility unknown. Click to open settings."
        )
    }

    func testPermissionPresentationUsesGrantedAndMissingStates() {
        let granted = AppPresentation.permission(
            for: PermissionSnapshot(camera: .granted, accessibility: .granted)
        )
        let missing = AppPresentation.permission(for: .unknown)

        XCTAssertEqual(granted.label, "Permissions OK")
        XCTAssertEqual(granted.tint, .green)
        XCTAssertEqual(missing.label, "Needs Camera + Accessibility")
        XCTAssertEqual(missing.tint, .orange)
    }

    func testPermissionStatusTintMapping() {
        XCTAssertEqual(AppPresentation.tint(for: .unknown), .orange)
        XCTAssertEqual(AppPresentation.tint(for: .granted), .green)
        XCTAssertEqual(AppPresentation.tint(for: .denied), .red)
        XCTAssertEqual(AppPresentation.tint(for: .restricted), .red)
    }

    func testCameraPresentationCoversCameraLifecycle() {
        XCTAssertEqual(AppPresentation.camera(for: .idle).label, "Camera Off")
        XCTAssertEqual(AppPresentation.camera(for: .starting).tint, .cyan)
        XCTAssertEqual(AppPresentation.camera(for: .running).label, "Camera On")
        XCTAssertEqual(AppPresentation.camera(for: .stopping).tint, .orange)

        let failed = AppPresentation.camera(for: .failed("No camera"))

        XCTAssertEqual(failed.label, "Camera Failed")
        XCTAssertEqual(failed.helpText, "No camera")
        XCTAssertEqual(failed.tint, .red)
    }

    func testHandDetectionPresentationCoversDetectionLifecycle() {
        XCTAssertEqual(AppPresentation.handDetection(for: .idle).label, "Hand Idle")
        XCTAssertEqual(AppPresentation.handDetection(for: .idle).tint, .gray)
        XCTAssertEqual(AppPresentation.handDetection(for: .looking).label, "Looking for Hand")
        XCTAssertEqual(AppPresentation.handDetection(for: .looking).tint, .cyan)
        XCTAssertEqual(AppPresentation.handDetection(for: .detected).label, "Hand Detected")
        XCTAssertEqual(AppPresentation.handDetection(for: .detected).tint, .green)
        XCTAssertEqual(AppPresentation.handDetection(for: .lost).label, "Hand Lost")
        XCTAssertEqual(AppPresentation.handDetection(for: .lost).tint, .orange)

        let failed = AppPresentation.handDetection(for: .failed("Vision request failed"))

        XCTAssertEqual(failed.label, "Hand Detection Failed")
        XCTAssertEqual(failed.helpText, "Vision request failed")
        XCTAssertEqual(failed.tint, .red)
    }
}
