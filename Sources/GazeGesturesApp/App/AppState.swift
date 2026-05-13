import Foundation

final class AppState: ObservableObject {
    @Published var mode: AppMode = .idle
    @Published var lastEventDescription: String = "Ready"
    @Published var permissions = PermissionSnapshot.placeholder
}

enum AppMode: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case blocked = "Blocked"
    case armed = "Armed"

    var id: String { rawValue }
}

enum PermissionKind: String, CaseIterable, Identifiable {
    case camera = "Camera"
    case accessibility = "Accessibility"

    var id: String { rawValue }
}

enum PermissionStatus: String {
    case unknown = "Unknown"
    case granted = "Granted"
    case denied = "Denied"
    case restricted = "Restricted"
}

struct PermissionSnapshot {
    var camera: PermissionStatus
    var accessibility: PermissionStatus

    static let placeholder = PermissionSnapshot(
        camera: .unknown,
        accessibility: .unknown
    )

    var canEnterGestureMode: Bool {
        camera == .granted && accessibility == .granted
    }

    var missingRequiredPermissions: [PermissionKind] {
        var missing: [PermissionKind] = []

        if camera != .granted {
            missing.append(.camera)
        }

        if accessibility != .granted {
            missing.append(.accessibility)
        }

        return missing
    }

    var summary: String {
        if canEnterGestureMode {
            return "Required permissions granted"
        }

        let missing = missingRequiredPermissions.map(\.rawValue).joined(separator: ", ")
        return "Missing: \(missing)"
    }
}
