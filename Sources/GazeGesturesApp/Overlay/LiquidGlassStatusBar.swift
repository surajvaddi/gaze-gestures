import SwiftUI

struct LiquidGlassStatusBar: View {
    @ObservedObject var appState: AppState

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

            Text(appState.mode.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(modeTint.opacity(0.16), in: Capsule())
                .foregroundStyle(modeTint)

            Text("⌃⌥⌘Space")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(width: 560, height: 54)
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
        case .armed:
            return .cyan
        }
    }
}
