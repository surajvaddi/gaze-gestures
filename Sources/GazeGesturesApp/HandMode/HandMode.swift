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
