import Foundation

enum HandModeAction: Equatable {
    case click(ScreenPoint)
    case drag(HandDragPhase)
    case scroll(HandScrollDelta)
    case freeze(Bool)
    case cancel
}

enum HandDragPhase: Equatable {
    case started(ScreenPoint)
    case moved(ScreenPoint)
    case ended(ScreenPoint)
}

struct HandScrollDelta: Equatable {
    var horizontal: Double
    var vertical: Double

    var isZero: Bool {
        horizontal == 0 && vertical == 0
    }
}

struct HandScrollConfiguration: Equatable {
    var minimumMovement: Double
    var horizontalScale: Double
    var verticalScale: Double

    static let conservativeDefault = HandScrollConfiguration(
        minimumMovement: 3,
        horizontalScale: 0.25,
        verticalScale: 0.25
    )
}

enum HandScrollIntent: Equatable {
    case none
    case scrolled(HandScrollDelta)
}

final class HandScrollIntentDetector {
    private let configuration: HandScrollConfiguration
    private var lastPoint: ScreenPoint?

    init(configuration: HandScrollConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func process(point: ScreenPoint?) -> HandScrollIntent {
        guard let point else {
            reset()
            return .none
        }

        guard let lastPoint else {
            self.lastPoint = point
            return .none
        }

        let movement = ScreenPoint(
            x: point.x - lastPoint.x,
            y: point.y - lastPoint.y
        )
        guard shouldScroll(for: movement) else {
            return .none
        }

        self.lastPoint = point
        return .scrolled(
            HandScrollDelta(
                horizontal: movement.x * configuration.horizontalScale,
                vertical: movement.y * configuration.verticalScale
            )
        )
    }

    func reset() {
        lastPoint = nil
    }

    private func shouldScroll(for movement: ScreenPoint) -> Bool {
        abs(movement.x) >= max(configuration.minimumMovement, 0)
            || abs(movement.y) >= max(configuration.minimumMovement, 0)
    }
}

enum HandModeActionState: Equatable {
    case idle
    case preparing(HandModeAction)
    case active(HandModeAction)
    case completed(HandModeAction)
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled:
            return true
        case .idle, .preparing, .active:
            return false
        }
    }
}

enum HandActionControlDecision: Equatable {
    case accepted(HandModeAction)
    case blockedFrozen(HandModeAction)
    case freezeChanged(Bool)
    case cancelled
}

final class HandActionControlController {
    private(set) var isFrozen: Bool

    init(isFrozen: Bool = false) {
        self.isFrozen = isFrozen
    }

    func evaluate(_ action: HandModeAction) -> HandActionControlDecision {
        switch action {
        case .freeze(let isFrozen):
            self.isFrozen = isFrozen
            return .freezeChanged(isFrozen)
        case .cancel:
            self.isFrozen = false
            return .cancelled
        case .click, .drag, .scroll:
            guard !self.isFrozen else {
                return .blockedFrozen(action)
            }

            return .accepted(action)
        }
    }
}

struct PinchDragConfiguration: Equatable {
    var holdDuration: TimeInterval
    var minimumMovement: Double

    static let conservativeDefault = PinchDragConfiguration(
        holdDuration: 0.45,
        minimumMovement: 2
    )
}

enum PinchDragIntent: Equatable {
    case none
    case started(ScreenPoint)
    case moved(ScreenPoint)
    case ended(ScreenPoint)
    case cancelled
}

final class PinchDragIntentTracker {
    private let configuration: PinchDragConfiguration
    private var pressStartTimestamp: TimeInterval?
    private var lastPoint: ScreenPoint?
    private var isDragging = false

    init(configuration: PinchDragConfiguration = .conservativeDefault) {
        self.configuration = configuration
    }

    func process(
        observation: PinchObservation,
        cursorPoint: ScreenPoint?
    ) -> PinchDragIntent {
        switch observation.state {
        case .pinching:
            guard let cursorPoint else {
                reset()
                return .cancelled
            }

            if pressStartTimestamp == nil {
                pressStartTimestamp = observation.timestamp
                lastPoint = cursorPoint
                return .none
            }

            if !isDragging,
               let pressStartTimestamp,
               observation.timestamp - pressStartTimestamp >= max(configuration.holdDuration, 0) {
                isDragging = true
                lastPoint = cursorPoint
                return .started(cursorPoint)
            }

            guard isDragging else {
                lastPoint = cursorPoint
                return .none
            }

            guard shouldEmitMove(to: cursorPoint) else {
                return .none
            }

            lastPoint = cursorPoint
            return .moved(cursorPoint)
        case .open:
            guard isDragging, let lastPoint else {
                reset()
                return .none
            }

            reset()
            return .ended(lastPoint)
        case .unknown:
            reset()
            return .cancelled
        }
    }

    func reset() {
        pressStartTimestamp = nil
        lastPoint = nil
        isDragging = false
    }

    private func shouldEmitMove(to point: ScreenPoint) -> Bool {
        guard let lastPoint else {
            return true
        }

        let deltaX = point.x - lastPoint.x
        let deltaY = point.y - lastPoint.y
        let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()

        return distance >= max(configuration.minimumMovement, 0)
    }
}
