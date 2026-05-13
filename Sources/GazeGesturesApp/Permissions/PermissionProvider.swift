import AppKit
import ApplicationServices
import AVFoundation
import Foundation

protocol PermissionProviding {
    func currentSnapshot() -> PermissionSnapshot
    func requestCameraAccess(completion: @escaping (PermissionSnapshot) -> Void)
    func requestAccessibilityTrust() -> PermissionSnapshot
    func openSystemSettings(for kind: PermissionKind)
}

final class SystemPermissionProvider: PermissionProviding {
    func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            camera: cameraStatus(),
            accessibility: accessibilityStatus()
        )
    }

    func requestCameraAccess(completion: @escaping (PermissionSnapshot) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            let snapshot = self?.currentSnapshot() ?? .placeholder

            DispatchQueue.main.async {
                completion(snapshot)
            }
        }
    }

    func requestAccessibilityTrust() -> PermissionSnapshot {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
        return currentSnapshot()
    }

    func openSystemSettings(for kind: PermissionKind) {
        guard let url = URL(string: kind.systemSettingsURLString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func cameraStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unknown
        }
    }

    private func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .unknown
    }
}

private extension PermissionKind {
    var systemSettingsURLString: String {
        switch self {
        case .camera:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }
    }
}
