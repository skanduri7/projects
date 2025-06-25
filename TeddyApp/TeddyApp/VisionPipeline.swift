//
//  VisionPipeline.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/24/25.
//
//
//  VisionPipeline.swift
//
import Foundation
import Vision
import CoreVideo          //  CVPixelBuffer

/// Throttled OCR on incoming CVPixelBuffers
final class VisionPipeline {

    // MARK: configuration
    private let minInterval: TimeInterval = 0.5          // seconds between OCR passes
    private let queue        = DispatchQueue(label: "vision.ocr", qos: .userInitiated)

    // MARK: state
    private var lastRun  = Date.distantPast
    private let textReq  = VNRecognizeTextRequest()

    init() {
        textReq.recognitionLevel = .accurate
        textReq.usesLanguageCorrection = true
    }

    func enqueue(_ px: CVPixelBuffer) {
        guard Date().timeIntervalSince(lastRun) >= minInterval else { return }
        lastRun = Date()

        // Copy the pixel-buffer reference for the async job
        let buffer = px
        queue.async { [textReq] in
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer,
                                                orientation: .up,
                                                options: [:])
            do {
                try handler.perform([textReq])
                if let obs = textReq.results {
                    self.report(obs, size: buffer)
                }
            } catch {
                print("⚠️ Vision OCR error:", error)
            }
        }
    }

    // Simple console dump; replace with your own downstream handling
    private func report(_ obs: [VNRecognizedTextObservation], size buffer: CVPixelBuffer) {
        let w = CGFloat(CVPixelBufferGetWidth(buffer))
        let h = CGFloat(CVPixelBufferGetHeight(buffer))

        FusionEngine.shared.ingestOCR(obs, displaySize: CGSize(width: w, height: h))
    }
}

