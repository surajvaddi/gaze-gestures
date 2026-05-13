import XCTest
@testable import GazeGesturesApp

final class HotkeyRegistrationFailureTests: XCTestCase {
    func testFailureMessagesIncludeStatusCodes() {
        XCTAssertEqual(
            HotkeyRegistrationFailure.eventHandlerInstallFailed(-1).userMessage,
            "Hotkeys unavailable: event handler failed (-1)"
        )
        XCTAssertEqual(
            HotkeyRegistrationFailure.activationHotkeyFailed(-9878).userMessage,
            "Activation hotkey unavailable (-9878)"
        )
        XCTAssertEqual(
            HotkeyRegistrationFailure.emergencyExitHotkeyFailed(-9878).userMessage,
            "Emergency exit hotkey unavailable (-9878)"
        )
    }
}
