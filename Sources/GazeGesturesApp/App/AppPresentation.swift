import Foundation

enum PresentationTint {
    case gray
    case orange
    case cyan
    case green
    case red
    case purple
    case blue
}

struct ModePresentation: Equatable {
    var label: String
    var helpText: String
    var tint: PresentationTint
}

struct PermissionPresentation: Equatable {
    var label: String
    var helpText: String
    var tint: PresentationTint
}

enum AppPresentation {
    static func mode(
        for mode: AppMode,
        permissions: PermissionSnapshot
    ) -> ModePresentation {
        switch mode {
        case .idle:
            return ModePresentation(
                label: "Idle: Off",
                helpText: "Gesture control is off. Press Control-Option-Command-Space to request activation.",
                tint: .gray
            )
        case .blocked:
            return ModePresentation(
                label: "Blocked: Open Settings",
                helpText: "\(permissions.summary). Click to open settings.",
                tint: .orange
            )
        case .armed:
            return ModePresentation(
                label: "Armed: Ready",
                helpText: "Gesture mode is armed. Press Control-Option-Command-Escape for emergency exit.",
                tint: .cyan
            )
        case .handGesture:
            return ModePresentation(
                label: "Hand: Active",
                helpText: "Hand gesture mode is active. Press Control-Option-Command-Escape for emergency exit.",
                tint: .green
            )
        case .gazeGesture:
            return ModePresentation(
                label: "Gaze: Active",
                helpText: "Gaze-enhanced gesture mode is active. Press Control-Option-Command-Escape for emergency exit.",
                tint: .purple
            )
        case .suspended:
            return ModePresentation(
                label: "Suspended",
                helpText: "Gesture control is temporarily suspended.",
                tint: .blue
            )
        case .emergencyExiting:
            return ModePresentation(
                label: "Exiting",
                helpText: "Emergency exit is stopping active gesture services.",
                tint: .red
            )
        }
    }

    static func permission(for permissions: PermissionSnapshot) -> PermissionPresentation {
        if permissions.canEnterGestureMode {
            return PermissionPresentation(
                label: "Permissions OK",
                helpText: "Required permissions are granted. Click to open Gaze Gestures settings.",
                tint: .green
            )
        }

        return PermissionPresentation(
            label: permissions.permissionCallout,
            helpText: "\(permissions.summary). Click to open settings and permission links.",
            tint: .orange
        )
    }

    static func tint(for status: PermissionStatus) -> PresentationTint {
        switch status {
        case .granted:
            return .green
        case .denied, .restricted:
            return .red
        case .unknown:
            return .orange
        }
    }
}
