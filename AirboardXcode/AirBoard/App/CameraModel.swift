// CameraModel.swift
import Foundation
import AVFoundation

/// Manages a running AVCaptureSession for the default video device.
final class CameraModel: ObservableObject {
    let session = AVCaptureSession()

    init() {
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Choose the default video device (e.g. the built-in webcam)
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("Error: No video device available")
            session.commitConfiguration()
            return
        }

        // Create an input from that device
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("Error: Cannot add video input")
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.commitConfiguration()

        // Start the capture on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
}
