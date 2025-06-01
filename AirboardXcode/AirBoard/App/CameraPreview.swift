import SwiftUI
import AVFoundation

/// A SwiftUI wrapper around an AVCaptureVideoPreviewLayer on macOS.
/// This shows the live webcam feed full-screen (or full-view).
struct CameraPreview: NSViewRepresentable {
    class PreviewNSView: NSView {
        // We override wantsUpdateLayer to ensure our layer is created
        override var wantsUpdateLayer: Bool { true }
    }

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.wantsLayer = true

        // 1) Create and configure an AVCaptureSession
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // 2) Find the default video device (built-in FaceTime camera, etc.)
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            return view
        }
        session.addInput(input)

        // 3) Create a preview layer and attach it to our view’s layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        if let conn = previewLayer.connection {
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = true
                }
        
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        view.layer = previewLayer

        // 4) Start the session
        session.startRunning()

        // 5) Keep a strong reference to session in the view’s layer so it doesn’t get deallocated
        (view.layer as? AVCaptureVideoPreviewLayer)?.session = session

        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        // Nothing to do here; the preview layer automatically updates.
    }
}
