import Foundation

final class AppState: ObservableObject {
    @Published var mode: AppMode = .idle
}

enum AppMode: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case armed = "Armed"

    var id: String { rawValue }
}
