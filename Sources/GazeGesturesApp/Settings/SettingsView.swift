import SwiftUI

struct PermissionActions {
    var refresh: () -> Void
    var requestCamera: () -> Void
    var requestAccessibility: () -> Void
    var openCameraSettings: () -> Void
    var openAccessibilitySettings: () -> Void
}

struct SettingsView: View {
    @ObservedObject var appState: AppState
    let permissionActions: PermissionActions

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gaze Gestures")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Step 3B: real permission checks")
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Current mode", value: appState.mode.rawValue)
                LabeledContent("Last event", value: appState.lastEventDescription)
                LabeledContent(
                    "Permission gate",
                    value: AppPresentation.permission(for: appState.permissions).label
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                permissionRow(
                    title: "Camera",
                    status: appState.permissions.camera,
                    detail: "Needed for local hand and gaze tracking.",
                    requestTitle: "Request Camera",
                    requestAction: permissionActions.requestCamera,
                    openAction: permissionActions.openCameraSettings
                )

                permissionRow(
                    title: "Accessibility",
                    status: appState.permissions.accessibility,
                    detail: "Needed to send mouse and keyboard actions.",
                    requestTitle: "Request Trust",
                    requestAction: permissionActions.requestAccessibility,
                    openAction: permissionActions.openAccessibilitySettings
                )
            }

            #if DEBUG
            developmentModePicker
            #endif

            HStack {
                Button("Refresh Permissions") {
                    permissionActions.refresh()
                }

                Spacer()
            }

            Text("Use Control-Option-Command-Space to request activation. Gesture mode enters Armed only when Camera and Accessibility are granted. Control-Option-Command-Escape always returns to Idle.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 460)
    }

    private func permissionRow(
        title: String,
        status: PermissionStatus,
        detail: String,
        requestTitle: String,
        requestAction: @escaping () -> Void,
        openAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.medium)

                Text(status.rawValue)
                    .foregroundStyle(statusColor(for: status))
                    .font(.caption)

                Text(detail)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Spacer()

            Button(requestTitle) {
                requestAction()
            }

            Button("Open macOS Settings") {
                openAction()
            }
        }
    }

    private var developmentModePicker: some View {
        Picker("Development mode", selection: $appState.mode) {
            ForEach(AppMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private func statusColor(for status: PermissionStatus) -> Color {
        AppPresentation.tint(for: status).color
    }
}
