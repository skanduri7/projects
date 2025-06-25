//
//  FusionEngine.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//
import Foundation
import CoreGraphics
import Vision

/// Thread-safe singleton that merges OCR + AX data.
final class FusionEngine {

    static let shared = FusionEngine()
    private init() {}

    /// A single text blob with its rect and provenance.
    struct Item {
        enum Source { case ax, ocr }
        var text : String
        var rect : CGRect    // in display pixels
        var src  : Source
        var role : String
    }

    private var items = [Item]()       // current snapshot
    private let lock  = NSLock()

    // ───────── ingest OCR ─────────
    func ingestOCR(_ obs: [VNRecognizedTextObservation], displaySize: CGSize) {
        lock.lock(); defer { lock.unlock() }

        for ob in obs {
            guard let best = ob.topCandidates(1).first else { continue }
            let bb = ob.boundingBox
            let rect = CGRect(x: bb.minX * displaySize.width,
                              y: bb.minY * displaySize.height,
                              width: bb.width * displaySize.width,
                              height: bb.height * displaySize.height)

            let item = Item(text: best.string, rect: rect, src: .ocr, role: "")
            items.append(item)
            ContextStore.shared.insert(item)
        }
        flushIfNeeded()
    }

    // ───────── ingest AX ─────────
    func ingestAX(role: String, value: String?, rect: CGRect) {
        guard let val = value, !val.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }

        // Prefer AX value: remove overlapping OCR boxes
        items.removeAll { $0.src == .ocr && $0.rect.intersection(rect).area / $0.rect.area > 0.5 }
        let item = Item(text: val, rect: rect, src: .ax, role: role)
        items.append(item)
        ContextStore.shared.insert(item)
        flushIfNeeded()
    }

    // ───────── simple demo output ─────────
    private func flushIfNeeded() {
        guard items.count > 30 else { return }      // arbitrary batch size
//        print("──────── FUSED SNAPSHOT ────────")
//        for i in items {
//            print(i.src == .ax ? "AX " : "OCR", "→", i.text, "@", i.rect.integral)
//        }
//        print("────────────────────────────────")
        items.removeAll()
    }
}

fileprivate extension CGRect {
    var area: CGFloat { width * height }
}

