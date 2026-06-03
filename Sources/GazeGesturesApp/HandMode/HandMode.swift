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
