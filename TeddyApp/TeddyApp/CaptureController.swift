import ScreenCaptureKit
import AppKit
import AVFoundation

/// Captures the main display at 30 fps and logs a timestamp for every frame.
final class CaptureController: NSObject, SCStreamOutput, SCStreamDelegate {
    

    private var stream: SCStream?
    private var output: SCStreamOutput?
    private let sampleQ = DispatchQueue(label: "sample.queue", qos: .userInitiated)
    private let ocr = VisionPipeline()

    func start() {
        Task { @MainActor in
            do {
                // 1️⃣  Enumerate shareable content
                let content = try await SCShareableContent
                    .excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    print("❌  No display found"); return
                }

                // 2️⃣  Configure "capture everything on that display"
                let filter = SCContentFilter(display: display, excludingWindows: [])

                // 3️⃣  Stream @ native size, 30 fps, BGRA
                let cfg = SCStreamConfiguration()
                cfg.width  = Int(display.width)
                cfg.height = Int(display.height)
                cfg.pixelFormat          = kCVPixelFormatType_32BGRA
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                cfg.queueDepth           = 4          // buffering

                // 4️⃣  Build the stream
                let stream = SCStream(filter: filter, configuration: cfg, delegate: self)
                self.stream = stream

                // 5️⃣  Add an output so frames actually get delivered

                try stream.addStreamOutput(          // ← self conforms to SCStreamOutput
                        self,
                        type: .screen,
                        sampleHandlerQueue: sampleQ)

                // 6️⃣  Go!
                try await stream.startCapture()
                print("✅  Screen capture started")

            } catch {
                print("❌  Capture error:", error)
            }
        }
    }

    // MARK: - SCStreamOutput  (frames land here)

//    func stream(_ stream: SCStream,
//                didOutputSampleBuffer sbuf: CMSampleBuffer,
//                of type: SCStreamOutputType) {
//        let ts = CMSampleBufferGetPresentationTimeStamp(sbuf).seconds
//        print(String(format: "frame @ %.3f s", ts))
//        // TODO: send sbuf.imageBuffer to Vision / Core ML here
//    }
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sbuf: CMSampleBuffer,
                of type: SCStreamOutputType) {

        guard let px = sbuf.imageBuffer else { return }
        ocr.enqueue(px)                 // ← OCR every ~0.5 s
        // (keep or remove the timestamp print)
        let ts = CMSampleBufferGetPresentationTimeStamp(sbuf).seconds
        //print(String(format: "frame @ %.3f s", ts))
    }


    // MARK: - SCStreamDelegate (errors, status)

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("⚠️  Stream stopped:", error)
    }
}
