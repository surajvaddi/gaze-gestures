import Foundation

final class AppState: ObservableObject {
    @Published var mode: AppMode = .idle
    @Published var lastEventDescription: String = "Ready"

    func activateGestureMode() {
        guard mode == .idle else {
            lastEventDescription = "Already armed"
            return
        }

        mode = .armed
        lastEventDescription = "Activation hotkey received"
    }

    func emergencyExit() {
        mode = .idle
        lastEventDescription = "Emergency exit"
    }
}

enum AppMode: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case armed = "Armed"

    var id: String { rawValue }
}
