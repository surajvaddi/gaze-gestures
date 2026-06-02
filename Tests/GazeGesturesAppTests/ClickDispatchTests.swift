import XCTest
@testable import GazeGesturesApp

final class ClickDispatchTests: XCTestCase {
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
