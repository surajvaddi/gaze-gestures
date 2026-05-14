import AVFoundation
import Foundation

protocol CameraSessionManaging: AnyObject {
    var onStateChange: ((CameraSessionState) -> Void)? { get set }

    func startSession()
    func stopSession()
}

final class CameraSessionManager: CameraSessionManaging {
    var onStateChange: ((CameraSessionState) -> Void)?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "local.gazegestures.camera-session")
    private var isConfigured = false

    func startSession() {
        publish(.starting)

        queue.async { [weak self] in
            guard let self else { return }

            do {
                try self.configureIfNeeded()

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                self.publish(self.session.isRunning ? .running : .failed("Camera session did not start"))
            } catch {
                self.publish(.failed(error.localizedDescription))
            }
        }
    }

    func stopSession() {
        publish(.stopping)

        queue.async { [weak self] in
            guard let self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            self.publish(.idle)
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraSessionError.noVideoDevice
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraSessionError.cannotAddVideoInput
        }

        session.addInput(input)
        isConfigured = true
    }

    private func publish(_ state: CameraSessionState) {
        DispatchQueue.main.async { [weak self] in
            self?.onStateChange?(state)
        }
    }
}

private enum CameraSessionError: LocalizedError {
    case noVideoDevice
    case cannotAddVideoInput

    var errorDescription: String? {
        switch self {
        case .noVideoDevice:
            return "No video camera is available"
        case .cannotAddVideoInput:
            return "Camera input could not be added"
        }
    }
}
