import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gaze Gestures")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Step 1: native menu bar app skeleton")
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Current mode", value: appState.mode.rawValue)

            Picker("Development mode", selection: $appState.mode) {
                ForEach(AppMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("This first slice proves the app lifecycle, menu bar controller, and settings window before camera, overlay, or gesture recognition are added.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }
}
