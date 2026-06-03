import ApplicationServices
import Foundation

enum ClickDispatchError: Error, Equatable {
    case accessibilityNotTrusted
    case eventCreationFailed
}

protocol ClickDispatching {
    @discardableResult
    func dispatchLeftClick(at point: ScreenPoint) -> Result<Void, ClickDispatchError>
    @discardableResult
    func dispatchLeftMouseDown(at point: ScreenPoint) -> Result<Void, ClickDispatchError>
    @discardableResult
    func dispatchLeftMouseDrag(to point: ScreenPoint) -> Result<Void, ClickDispatchError>
    @discardableResult
    func dispatchLeftMouseUp(at point: ScreenPoint) -> Result<Void, ClickDispatchError>
}

enum SafeClickRejectionReason: Equatable {
    case incorrectMode
    case missingReleaseIntent
    case hiddenCursor
    case lowConfidence
    case cooldownActive

    var userMessage: String {
        switch self {
        case .incorrectMode:
            return "incorrect mode"
        case .missingReleaseIntent:
            return "missing release intent"
        case .hiddenCursor:
            return "hidden cursor"
        case .lowConfidence:
            return "low confidence"
        case .cooldownActive:
            return "cooldown active"
        }
    }
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

struct ClickCooldownConfiguration: Equatable {
    var duration: TimeInterval

    static let conservativeDefault = ClickCooldownConfiguration(
        duration: 0.35
    )
}

final class ClickCooldownController {
    private let configuration: ClickCooldownConfiguration
    private var clickTimestamp: TimeInterval?

    init(configuration: ClickCooldownConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func registerClick(at timestamp: TimeInterval) {
        clickTimestamp = timestamp
    }

    func allowsClick(at timestamp: TimeInterval) -> Bool {
        guard let clickTimestamp else {
            return true
        }

        return timestamp >= clickTimestamp + max(configuration.duration, 0)
    }

    func reset() {
        clickTimestamp = nil
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
    private let accessibilityTrusted: () -> Bool

    init(accessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.accessibilityTrusted = accessibilityTrusted
    }

    @discardableResult
    func dispatchLeftClick(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        guard accessibilityTrusted() else {
            return .failure(.accessibilityNotTrusted)
        }

        guard postMouseEvent(.leftMouseDown, at: point),
              postMouseEvent(.leftMouseUp, at: point) else {
            return .failure(.eventCreationFailed)
        }

        return .success(())
    }

    @discardableResult
    func dispatchLeftMouseDown(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        dispatchMouseEvent(.leftMouseDown, at: point)
    }

    @discardableResult
    func dispatchLeftMouseDrag(to point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        dispatchMouseEvent(.leftMouseDragged, at: point)
    }

    @discardableResult
    func dispatchLeftMouseUp(at point: ScreenPoint) -> Result<Void, ClickDispatchError> {
        dispatchMouseEvent(.leftMouseUp, at: point)
    }

    private func dispatchMouseEvent(
        _ type: CGEventType,
        at point: ScreenPoint
    ) -> Result<Void, ClickDispatchError> {
        guard accessibilityTrusted() else {
            return .failure(.accessibilityNotTrusted)
        }

        guard postMouseEvent(type, at: point) else {
            return .failure(.eventCreationFailed)
        }

        return .success(())
    }

    private func postMouseEvent(_ type: CGEventType, at point: ScreenPoint) -> Bool {
        let cgPoint = CGPoint(x: point.x, y: point.y)

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: cgPoint,
            mouseButton: .left
        ) else {
            return false
        }

        event.post(tap: .cghidEventTap)
        return true
    }
}
