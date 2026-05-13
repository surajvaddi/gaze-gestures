import SwiftUI

struct LiquidGlassStatusBar: View {
    @ObservedObject var appState: AppState
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusDot

            VStack(alignment: .leading, spacing: 2) {
                Text("Gaze Gestures")
                    .font(.system(size: 13, weight: .semibold))

                Text(appState.lastEventDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                onOpenSettings()
            } label: {
                Text(permissionText)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(permissionTint.opacity(0.12), in: Capsule())
                    .foregroundStyle(permissionTint)
            }
            .buttonStyle(.plain)
            .help(permissionHelpText)

            Button {
                onOpenSettings()
            } label: {
                Text(modeText)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(modeTint.opacity(0.16), in: Capsule())
                    .foregroundStyle(modeTint)
            }
            .buttonStyle(.plain)
            .help(modeHelpText)

            Text("⌃⌥⌘Space")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(width: 680, height: 54)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.72)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(modeTint)
            .frame(width: 10, height: 10)
            .shadow(color: modeTint.opacity(0.55), radius: 8)
    }

    private var modeTint: Color {
        switch appState.mode {
        case .idle:
            return .gray
        case .blocked:
            return .orange
        case .armed:
            return .cyan
        }
    }

    private var permissionText: String {
        if appState.permissions.canEnterGestureMode {
            return "Permissions OK"
        }

        return appState.permissions.permissionCallout
    }

    private var permissionTint: Color {
        appState.permissions.canEnterGestureMode ? .green : .orange
    }

    private var permissionHelpText: String {
        if appState.permissions.canEnterGestureMode {
            return "Required permissions are granted. Click to open Gaze Gestures settings."
        }

        return "\(appState.permissions.summary). Click to open settings and permission links."
    }

    private var modeText: String {
        switch appState.mode {
        case .idle:
            return "Idle: Off"
        case .blocked:
            return "Blocked: Open Settings"
        case .armed:
            return "Armed: Ready"
        }
    }

    private var modeHelpText: String {
        switch appState.mode {
        case .idle:
            return "Gesture control is off. Press Control-Option-Command-Space to request activation."
        case .blocked:
            return "\(appState.permissions.summary). Click to open settings."
        case .armed:
            return "Gesture mode is armed. Press Control-Option-Command-Escape for emergency exit."
        }
    }
}
