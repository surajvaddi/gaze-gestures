import XCTest
@testable import GazeGesturesApp

final class ClickDispatchTests: XCTestCase {
    func testConservativeSafeClickGateDefaultsAreExplicit() {
        let configuration = SafeClickGateConfiguration.conservativeDefault

        XCTAssertEqual(configuration.minimumConfidence, 0.70)
    }

    func testConservativeClickCooldownDefaultsAreExplicit() {
        let configuration = ClickCooldownConfiguration.conservativeDefault

        XCTAssertEqual(configuration.duration, 0.35)
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

    func testPinchClickIntentTrackerStartsPressOnFirstPinch() {
        let tracker = PinchClickIntentTracker()
        let observation = pinchObservation(state: .pinching, timestamp: 1)

        XCTAssertEqual(
            tracker.process(observation),
            .pressStarted(observation)
        )
    }

    func testPinchClickIntentTrackerIgnoresHeldPinchAfterPressStarts() {
        let tracker = PinchClickIntentTracker()

        _ = tracker.process(pinchObservation(state: .pinching, timestamp: 1))

        XCTAssertEqual(
            tracker.process(pinchObservation(state: .pinching, timestamp: 2)),
            .none
        )
    }

    func testPinchClickIntentTrackerIgnoresOpenWithoutPriorPress() {
        let tracker = PinchClickIntentTracker()

        XCTAssertEqual(
            tracker.process(pinchObservation(state: .open, timestamp: 1)),
            .none
        )
    }

    func testPinchClickIntentTrackerCompletesReleaseAfterPinchThenOpen() {
        let tracker = PinchClickIntentTracker()
        let releaseObservation = pinchObservation(state: .open, timestamp: 2)

        _ = tracker.process(pinchObservation(state: .pinching, timestamp: 1))

        XCTAssertEqual(
            tracker.process(releaseObservation),
            .releaseCompleted(releaseObservation)
        )
    }

    func testPinchClickIntentTrackerResetClearsActivePress() {
        let tracker = PinchClickIntentTracker()

        _ = tracker.process(pinchObservation(state: .pinching, timestamp: 1))
        tracker.reset()

        XCTAssertEqual(
            tracker.process(pinchObservation(state: .open, timestamp: 2)),
            .none
        )
    }

    func testPinchClickIntentTrackerUnknownObservationClearsActivePress() {
        let tracker = PinchClickIntentTracker()

        _ = tracker.process(pinchObservation(state: .pinching, timestamp: 1))
        XCTAssertEqual(
            tracker.process(pinchObservation(state: .unknown, timestamp: 2)),
            .none
        )

        XCTAssertEqual(
            tracker.process(pinchObservation(state: .open, timestamp: 3)),
            .none
        )
    }

    func testClickCooldownAllowsClickBeforeFirstDispatch() {
        let cooldown = ClickCooldownController(
            configuration: ClickCooldownConfiguration(duration: 1)
        )

        XCTAssertTrue(cooldown.allowsClick(at: 10))
    }

    func testClickCooldownBlocksClickDuringCooldown() {
        let cooldown = ClickCooldownController(
            configuration: ClickCooldownConfiguration(duration: 1)
        )

        cooldown.registerClick(at: 10)

        XCTAssertFalse(cooldown.allowsClick(at: 10.99))
    }

    func testClickCooldownAllowsClickAfterDurationExpires() {
        let cooldown = ClickCooldownController(
            configuration: ClickCooldownConfiguration(duration: 1)
        )

        cooldown.registerClick(at: 10)

        XCTAssertTrue(cooldown.allowsClick(at: 11))
    }

    func testClickCooldownResetClearsCooldown() {
        let cooldown = ClickCooldownController(
            configuration: ClickCooldownConfiguration(duration: 1)
        )

        cooldown.registerClick(at: 10)
        cooldown.reset()

        XCTAssertTrue(cooldown.allowsClick(at: 10.50))
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

    func testRecordingClickDispatcherStoresDragEvents() {
        let dispatcher = RecordingClickDispatcher()

        XCTAssertTrue(dispatcher.dispatchLeftMouseDown(at: ScreenPoint(x: 10, y: 20)).isSuccess)
        XCTAssertTrue(dispatcher.dispatchLeftMouseDrag(to: ScreenPoint(x: 12, y: 22)).isSuccess)
        XCTAssertTrue(dispatcher.dispatchLeftMouseUp(at: ScreenPoint(x: 14, y: 24)).isSuccess)

        XCTAssertEqual(
            dispatcher.dragEvents,
            [
                .down(ScreenPoint(x: 10, y: 20)),
                .drag(ScreenPoint(x: 12, y: 22)),
                .up(ScreenPoint(x: 14, y: 24))
            ]
        )
    }

    func testCGEventClickDispatcherRejectsWhenAccessibilityIsNotTrusted() {
        let dispatcher = CGEventClickDispatcher(accessibilityTrusted: { false })

        XCTAssertEqual(
            dispatcher.dispatchLeftClick(at: ScreenPoint(x: 10, y: 20)).failure,
            .accessibilityNotTrusted
        )
        XCTAssertEqual(
            dispatcher.dispatchLeftMouseDown(at: ScreenPoint(x: 10, y: 20)).failure,
            .accessibilityNotTrusted
        )
        XCTAssertEqual(
            dispatcher.dispatchLeftMouseDrag(to: ScreenPoint(x: 10, y: 20)).failure,
            .accessibilityNotTrusted
        )
        XCTAssertEqual(
            dispatcher.dispatchLeftMouseUp(at: ScreenPoint(x: 10, y: 20)).failure,
            .accessibilityNotTrusted
        )
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
    private(set) var dragEvents: [RecordedDragEvent] = []

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

    func dispatchLeftMouseDown(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        recordDragEvent(.down(point))
    }

    func dispatchLeftMouseDrag(to point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        recordDragEvent(.drag(point))
    }

    func dispatchLeftMouseUp(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        recordDragEvent(.up(point))
    }

    private func recordDragEvent(_ event: RecordedDragEvent) -> Result<Void, ClickDispatchError> {
        guard case .success = result else {
            return result
        }

        dragEvents.append(event)
        return result
    }
}

private enum RecordedDragEvent: Equatable {
    case down(ScreenPoint)
    case drag(ScreenPoint)
    case up(ScreenPoint)
}

private func pinchObservation(
    state: PinchState,
    timestamp: TimeInterval,
    confidence: Double = 0.90
) -> PinchObservation {
    PinchObservation(
        state: state,
        thumbTip: nil,
        indexTip: nil,
        midpoint: NormalizedPoint(x: 0.4, y: 0.6),
        normalizedDistance: nil,
        confidence: confidence,
        timestamp: timestamp
    )
}
