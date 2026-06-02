import ApplicationServices
import Foundation

enum ClickDispatchError: Error, Equatable {
    case eventCreationFailed
}

protocol ClickDispatching {
    @discardableResult
    func dispatchLeftClick(at point: ScreenPoint) -> Result<Void, ClickDispatchError>
}

enum SafeClickRejectionReason: Equatable {
    case incorrectMode
    case missingReleaseIntent
    case hiddenCursor
    case lowConfidence
    case cooldownActive
}

enum SafeClickGateDecision: Equatable {
    case accepted(ScreenPoint)
    case rejected(SafeClickRejectionReason)
}

struct SafeClickGateConfiguration: Equatable {
    var minimumConfidence: Double

    static let conservativeDefault = SafeClickGateConfiguration(
        minimumConfidence: 0.70
    )
}

struct SafeClickGateRequest: Equatable {
    var mode: AppMode
    var virtualCursorState: VirtualCursorState
    var confidence: Double
    var isReleaseIntent: Bool
    var allowsClick: Bool
}

struct SafeClickGate {
    var configuration: SafeClickGateConfiguration

    init(configuration: SafeClickGateConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func evaluate(_ request: SafeClickGateRequest) -> SafeClickGateDecision {
        guard request.mode == .handGesture else {
            return .rejected(.incorrectMode)
        }

        guard request.isReleaseIntent else {
            return .rejected(.missingReleaseIntent)
        }

        guard case .visible(let point) = request.virtualCursorState else {
            return .rejected(.hiddenCursor)
        }

        guard request.confidence >= configuration.minimumConfidence else {
            return .rejected(.lowConfidence)
        }

        guard request.allowsClick else {
            return .rejected(.cooldownActive)
        }

        return .accepted(point)
    }
}

enum PinchClickIntent: Equatable {
    case none
    case pressStarted(PinchObservation)
    case releaseCompleted(PinchObservation)
}

final class PinchClickIntentTracker {
    private var hasActivePress = false

    func process(_ observation: PinchObservation) -> PinchClickIntent {
        switch observation.state {
        case .pinching where !hasActivePress:
            hasActivePress = true
            return .pressStarted(observation)
        case .pinching:
            return .none
        case .open where hasActivePress:
            hasActivePress = false
            return .releaseCompleted(observation)
        case .open:
            return .none
        case .unknown:
            reset()
            return .none
        }
    }

    func reset() {
        hasActivePress = false
    }
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
