import ApplicationServices
import Foundation

enum ClickDispatchError: Error, Equatable {
    case eventCreationFailed
}

protocol ClickDispatching {
    @discardableResult
    func dispatchLeftClick(at point: ScreenPoint) -> Result<Void, ClickDispatchError>
}

final class CGEventClickDispatcher: ClickDispatching {
    @discardableResult
    func dispatchLeftClick(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        let cgPoint = CGPoint(x: point.x, y: point.y)

        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: cgPoint,
            mouseButton: .left
        ),
            let mouseUp = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: cgPoint,
                mouseButton: .left
            ) else {
            return .failure(.eventCreationFailed)
        }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)

        return .success(())
    }
}
