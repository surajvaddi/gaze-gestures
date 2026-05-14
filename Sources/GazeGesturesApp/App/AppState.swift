import Foundation

final class AppState: ObservableObject {
    @Published var mode: AppMode = .idle
    @Published var lastEventDescription: String = "Ready"
    @Published var permissions = PermissionSnapshot.unknown
}

enum AppMode: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case blocked = "Blocked"
    case armed = "Armed"
    case handGesture = "Hand Gesture"
    case gazeGesture = "Gaze Gesture"
    case suspended = "Suspended"
    case emergencyExiting = "Emergency Exiting"

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

    static let unknown = PermissionSnapshot(
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

        let missing = missingRequiredPermissions
            .map { "\($0.rawValue) \(status(for: $0).rawValue.lowercased())" }
            .joined(separator: ", ")

        return "Missing: \(missing)"
    }

    var missingPermissionNames: String {
        let names = missingRequiredPermissions.map(\.rawValue)

        switch names.count {
        case 0:
            return "None"
        case 1:
            return names[0]
        default:
            return names.joined(separator: " + ")
        }
    }

    var permissionCallout: String {
        if canEnterGestureMode {
            return "Camera and Accessibility granted"
        }

        return "Needs \(missingPermissionNames)"
    }

    func status(for kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .camera:
            return camera
        case .accessibility:
            return accessibility
        }
    }
}
