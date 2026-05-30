import SwiftUI

struct LiquidGlassStatusBar: View {
    @ObservedObject var appState: AppState
    let onOpenSettings: () -> Void

    var body: some View {
        let mode = AppPresentation.mode(
            for: appState.mode,
            permissions: appState.permissions
        )
        let permission = AppPresentation.permission(for: appState.permissions)
        let camera = AppPresentation.camera(for: appState.cameraSessionState)
        let handDetection = AppPresentation.handDetection(for: appState.handDetectionState)

        HStack(spacing: 12) {
            statusDot(mode: mode)

            VStack(alignment: .leading, spacing: 2) {
                Text("Gaze Gestures")
                    .font(.system(size: 13, weight: .semibold))

                Text(appState.lastEventDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Button {
                onOpenSettings()
            } label: {
                Text(permission.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(permission.tint.color.opacity(0.12), in: Capsule())
                    .foregroundStyle(permission.tint.color)
            }
            .buttonStyle(.plain)
            .help(permission.helpText)
            .frame(maxWidth: 190)

            Button {
                onOpenSettings()
            } label: {
                Text(mode.label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(mode.tint.color.opacity(0.16), in: Capsule())
                    .foregroundStyle(mode.tint.color)
            }
            .buttonStyle(.plain)
            .help(mode.helpText)
            .frame(maxWidth: 170)

            Text(camera.label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(camera.tint.color.opacity(0.13), in: Capsule())
                .foregroundStyle(camera.tint.color)
                .help(camera.helpText)
                .frame(maxWidth: 130)

            Text(handDetection.label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(handDetection.tint.color.opacity(0.13), in: Capsule())
                .foregroundStyle(handDetection.tint.color)
                .help(handDetection.helpText)
                .frame(maxWidth: 150)

            Text("⌃⌥⌘Space")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(width: 940, height: 54)
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

    private func statusDot(mode: ModePresentation) -> some View {
        Circle()
            .fill(mode.tint.color)
            .frame(width: 10, height: 10)
            .shadow(color: mode.tint.color.opacity(0.55), radius: 8)
    }
}

extension PresentationTint {
    var color: Color {
        switch self {
        case .gray:
            return .gray
        case .orange:
            return .orange
        case .cyan:
            return .cyan
        case .green:
            return .green
        case .red:
            return .red
        case .purple:
            return .purple
        case .blue:
            return .blue
        }
    }
}
