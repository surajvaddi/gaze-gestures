import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gaze Gestures")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Step 3A: safety state machine")
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Current mode", value: appState.mode.rawValue)
            LabeledContent("Last event", value: appState.lastEventDescription)
            LabeledContent("Permission gate", value: appState.permissions.summary)
            LabeledContent("Camera", value: appState.permissions.camera.rawValue)
            LabeledContent("Accessibility", value: appState.permissions.accessibility.rawValue)

            Picker("Development mode", selection: $appState.mode) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Use Control-Option-Command-Space to request activation. In Step 3A, permission checks are placeholders, so activation routes to Blocked. Control-Option-Command-Escape always returns to Idle.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }
}
