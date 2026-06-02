import XCTest
@testable import GazeGesturesApp

final class ClickDispatchTests: XCTestCase {
    func testConservativeSafeClickGateDefaultsAreExplicit() {
        let configuration = SafeClickGateConfiguration.conservativeDefault

        XCTAssertEqual(configuration.minimumConfidence, 0.70)
    }

    func testSafeClickGateAcceptsHandGestureReleaseWithVisibleCursorAndConfidence() {
        let gate = SafeClickGate(configuration: SafeClickGateConfiguration(minimumConfidence: 0.80))

        XCTAssertEqual(
            gate.evaluate(
                SafeClickGateRequest(
                    mode: .handGesture,
                    virtualCursorState: .visible(ScreenPoint(x: 100, y: 200)),
                    confidence: 0.85,
                    isReleaseIntent: true,
                    allowsClick: true
                )
            ),
            .accepted(ScreenPoint(x: 100, y: 200))
        )
    }

    func testSafeClickGateRejectsIncorrectMode() {
        let gate = SafeClickGate()

        XCTAssertEqual(
            gate.evaluate(
                SafeClickGateRequest(
                    mode: .armed,
                    virtualCursorState: .visible(ScreenPoint(x: 100, y: 200)),
                    confidence: 1,
                    isReleaseIntent: true,
                    allowsClick: true
                )
            ),
            .rejected(.incorrectMode)
        )
    }

    func testSafeClickGateRejectsMissingReleaseIntent() {
        let gate = SafeClickGate()

        XCTAssertEqual(
            gate.evaluate(
                SafeClickGateRequest(
                    mode: .handGesture,
                    virtualCursorState: .visible(ScreenPoint(x: 100, y: 200)),
                    confidence: 1,
                    isReleaseIntent: false,
                    allowsClick: true
                )
            ),
            .rejected(.missingReleaseIntent)
        )
    }

    func testSafeClickGateRejectsHiddenCursor() {
        let gate = SafeClickGate()

        XCTAssertEqual(
            gate.evaluate(
                SafeClickGateRequest(
                    mode: .handGesture,
                    virtualCursorState: .hidden,
                    confidence: 1,
                    isReleaseIntent: true,
                    allowsClick: true
                )
            ),
            .rejected(.hiddenCursor)
        )
    }

    func testSafeClickGateRejectsLowConfidence() {
        let gate = SafeClickGate(configuration: SafeClickGateConfiguration(minimumConfidence: 0.80))

        XCTAssertEqual(
            gate.evaluate(
                SafeClickGateRequest(
                    mode: .handGesture,
                    virtualCursorState: .visible(ScreenPoint(x: 100, y: 200)),
                    confidence: 0.79,
                    isReleaseIntent: true,
                    allowsClick: true
                )
            ),
            .rejected(.lowConfidence)
        )
    }

    func testSafeClickGateRejectsActiveCooldown() {
        let gate = SafeClickGate()

        XCTAssertEqual(
            gate.evaluate(
                SafeClickGateRequest(
                    mode: .handGesture,
                    virtualCursorState: .visible(ScreenPoint(x: 100, y: 200)),
                    confidence: 1,
                    isReleaseIntent: true,
                    allowsClick: false
                )
            ),
            .rejected(.cooldownActive)
        )
    }

    func testRecordingClickDispatcherStoresLeftClickPoints() {
        let dispatcher = RecordingClickDispatcher()

        XCTAssertTrue(dispatcher.dispatchLeftClick(at: ScreenPoint(x: 10, y: 20)).isSuccess)
        XCTAssertTrue(dispatcher.dispatchLeftClick(at: ScreenPoint(x: 30, y: 40)).isSuccess)

        XCTAssertEqual(
            dispatcher.leftClickPoints,
            [
                ScreenPoint(x: 10, y: 20),
                ScreenPoint(x: 30, y: 40)
            ]
        )
    }

    func testRecordingClickDispatcherCanSurfaceFailureWithoutRecordingPoint() {
        let dispatcher = RecordingClickDispatcher(result: .failure(.eventCreationFailed))

        XCTAssertEqual(
            dispatcher.dispatchLeftClick(at: ScreenPoint(x: 10, y: 20)).failure,
            .eventCreationFailed
        )
        XCTAssertEqual(dispatcher.leftClickPoints, [])
    }
}

private extension Result where Success == Void, Failure == ClickDispatchError {
    var isSuccess: Bool {
        guard case .success = self else {
            return false
        }

        return true
    }

    var failure: ClickDispatchError? {
        guard case .failure(let failure) = self else {
            return nil
        }

        return failure
    }
}

private final class RecordingClickDispatcher: ClickDispatching {
    private let result: Result<Void, ClickDispatchError>
    private(set) var leftClickPoints: [ScreenPoint] = []

    init(result: Result<Void, ClickDispatchError> = .success(())) {
        self.result = result
    }

    func dispatchLeftClick(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        guard case .success = result else {
            return result
        }

        leftClickPoints.append(point)
        return result
    }
}
