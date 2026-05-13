import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gaze Gestures")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Step 2: global hotkeys and sticky liquid glass bar")
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Current mode", value: appState.mode.rawValue)
            LabeledContent("Last event", value: appState.lastEventDescription)

            Picker("Development mode", selection: $appState.mode) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Use Control-Option-Command-Space to arm the interface. Use Control-Option-Command-Escape as the emergency exit. The top bar is a development overlay and ignores mouse input.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }
}
