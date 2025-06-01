// AirBoard/Models/CanvasState.swift
import SwiftUI
import Combine
import Vision
import AppKit

final class CanvasState: ObservableObject {
    @Published var drawables: [Drawable] = []
    @Published var currentStroke: Stroke? = nil
    @Published var cameraOffset: CGSize = .zero
    @Published var cameraScale: CGFloat = 1.0
    
    private let alpha: CGFloat = 0.2
    //private let minDistance: CGFloat = 4.0
    
    private var lastLeftPos: CGPoint? = nil
    private var lastPinch: CGFloat? = nil
    
    private var lastSmoothed: CGPoint?
    
    func updateCameraZoom(pinch: CGFloat?, at anchor: CGPoint?, canvasSize: CGSize) {
        let activePinchThreshold: CGFloat = 0.2
        

        guard let pinch = pinch, pinch < activePinchThreshold else {
            lastPinch = nil
            return
        }
        
        guard let anchor = anchor else { return }

        // Zoom (scale)
        if let last = lastPinch {
            let delta = pinch - last
            let zoomFactor = 1.0 + delta * 4.0
            let newScale = max(0.5, min(cameraScale * zoomFactor, 3.0))

                // Convert normalized anchor (0...1) to pixel space
            let anchorInPixels = CGPoint(x: anchor.x * canvasSize.width,
                                            y: anchor.y * canvasSize.height)

                // Compute shift needed to keep anchor in place
            let scaleRatio = newScale / cameraScale
            cameraOffset.width = anchorInPixels.x - (anchorInPixels.x - cameraOffset.width) * scaleRatio
            cameraOffset.height = anchorInPixels.y - (anchorInPixels.y - cameraOffset.height) * scaleRatio

            cameraScale = newScale
        }

        lastPinch = pinch
    }


    // Begin a new stroke when pen-down
    func startStroke(color: Color = .white, lineWidth: CGFloat = 2.0) {
        lastSmoothed = nil
        currentStroke = Stroke(color: color, lineWidth: lineWidth)
    }

    // Add points while pen is down
    func addPointToCurrentStroke(_ point: CGPoint) {
        print("Point received: \(point)")
        guard var stroke = currentStroke else { return }
        
        stroke.rawPoints.append(point)
        
        let smoothed: CGPoint
        if let last = lastSmoothed {
                // Low‐pass: smoothed_new = α·raw + (1−α)·last_smoothed
            let sx = alpha * point.x + (1 - alpha) * last.x
            let sy = alpha * point.y + (1 - alpha) * last.y
            smoothed = CGPoint(x: sx, y: sy)
        } else {
            smoothed = point
        }
    
//        if let last = lastSmoothed {
//            let dx = smoothed.x - last.x
//            let dy = smoothed.y - last.y
//            let dist = hypot(dx, dy)
//            if dist < minDistance {
//                // Don’t append: too little movement
//                currentStroke = stroke
//                return
//            }
//        }
        stroke.smoothedPoints.append(smoothed)
        currentStroke = stroke
        lastSmoothed = smoothed
    }

    // When pen-up happens, end stroke and run recognition
    func endCurrentStroke() {
        guard let stroke = currentStroke else { return }
        defer { currentStroke = nil }

        // 1) Try OCR via Vision
        if let textSymbol = tryRecognizeText(from: stroke) {
            drawables.append(.symbol(textSymbol))
            return
        }

        // 2) Try circle
        if let (center, radius) = Self.isCircle(points: stroke.smoothedPoints) {
            let symbol = Symbol(type: .circle(center: center, radius: radius),
                                color: stroke.color,
                                lineWidth: stroke.lineWidth)
            drawables.append(.symbol(symbol))
            return
        }

        // 3) Try rectangle
        if let (origin, size) = Self.isRectangle(points: stroke.smoothedPoints) {
            let symbol = Symbol(type: .rectangle(origin: origin, size: size),
                                color: stroke.color,
                                lineWidth: stroke.lineWidth)
            drawables.append(.symbol(symbol))
            return
        }

        // 4) Fallback: raw freehand stroke
        drawables.append(.stroke(stroke))
    }

    // MARK: — OCR helper

    private func tryRecognizeText(from stroke: Stroke) -> Symbol? {
        guard let cgImage = rasterizeStroke(stroke) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results, !observations.isEmpty else {
            return nil
        }
        // Take top‐candidate string if length == 1
        if let candidate = observations[0].topCandidates(1).first,
           candidate.string.count == 1 {
            let char = candidate.string
            // Compute bounding‐box center for stroke
            let pts = stroke.points
            let xs = pts.map { $0.x }, ys = pts.map { $0.y }
            let center = CGPoint(x: xs.reduce(0,+)/CGFloat(xs.count),
                                 y: ys.reduce(0,+)/CGFloat(ys.count))
            return Symbol(type: .text(char, center: center),
                          color: stroke.color,
                          lineWidth: stroke.lineWidth)
        }
        return nil
    }

    // Draw stroke into a 256×256 grayscale image for OCR
    private func rasterizeStroke(_ stroke: Stroke) -> CGImage? {
        let size = CGSize(width: 512, height: 512)

        // 1) Create an NSBitmapImageRep that is 256×256, 8 bits per sample, grayscale
        guard let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 1,
                hasAlpha: false,
                isPlanar: false,
                colorSpaceName: .calibratedWhite,
                bytesPerRow: 0,
                bitsPerPixel: 0
        ) else {
            return nil
        }

        // 2) Create a CoreGraphics context from that bitmap
        guard let cgContext = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
            return nil
        }

        // 3) Fill the entire background with black
        cgContext.setFillColor(NSColor.black.cgColor)
        cgContext.fill(CGRect(origin: .zero, size: size))

        // 4) Set stroke color to white and line width
        cgContext.setStrokeColor(NSColor.white.cgColor)
        cgContext.setLineWidth(8.0)
        cgContext.setLineCap(.round)

        // 5) Map each normalized point [0…1] → pixel [0…256], flipping Y
        let pts: [CGPoint] = stroke.smoothedPoints.map { p in
            CGPoint(
                x: p.x * size.width,
                y: (1.0 - p.y) * size.height
            )
        }

        // 6) Draw the path if we have at least 2 points
        if let first = pts.first {
            cgContext.beginPath()
            cgContext.move(to: first)
            for pt in pts.dropFirst() {
                cgContext.addLine(to: pt)
            }
            cgContext.strokePath()
        }

        // 7) Extract a CGImage from our 256×256 context
        return cgContext.makeImage()
    }
    // MARK: — Circle heuristic

    private static func isCircle(points: [CGPoint]) -> (CGPoint, CGFloat)? {
        guard points.count > 5 else { return nil }
        guard let first = points.first, let last = points.last else { return nil }
        let closingDist = hypot(first.x - last.x, first.y - last.y)

        let xs = points.map { $0.x }, ys = points.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let bboxSize = max(maxX - minX, maxY - minY)
        // require roughly closed loop (within 20% of bbox)
        if closingDist > bboxSize * 0.2 { return nil }

        let center = CGPoint(x: (minX + maxX)/2, y: (minY + maxY)/2)
        let radii = points.map { hypot($0.x - center.x, $0.y - center.y) }
        let meanRadius = radii.reduce(0, +) / CGFloat(radii.count)
        let variance = radii.map { pow($0 - meanRadius, 2) }.reduce(0, +) / CGFloat(radii.count)

        if variance < pow(bboxSize/20, 2) {
            return (center, meanRadius)
        }
        return nil
    }

    // MARK: — Rectangle heuristic

    private static func isRectangle(points: [CGPoint]) -> (CGPoint, CGSize)? {
        guard points.count > 20 else { return nil }

        let xs = points.map { $0.x }, ys = points.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let width = maxX - minX, height = maxY - minY

        let minSize: CGFloat = 0.1
        if width < minSize || height < minSize { return nil }

        // Reject long skinny lines pretending to be rectangles
        let aspectRatio = max(width, height) / min(width, height)
        if aspectRatio > 4.0 { return nil }

        let origin = CGPoint(x: minX, y: minY)
        let size = CGSize(width: width, height: height)
        let tolX = width * 0.1, tolY = height * 0.1

        let nearEdgeCount = points.filter { p in
            let onLeft   = abs(p.x - minX) < tolX
            let onRight  = abs(p.x - maxX) < tolX
            let onTop    = abs(p.y - maxY) < tolY
            let onBottom = abs(p.y - minY) < tolY
            return onLeft || onRight || onTop || onBottom
        }.count

        let edgeRatio = CGFloat(nearEdgeCount) / CGFloat(points.count)
        if edgeRatio > 0.9 {
            return (origin, size)
        }

        return nil
    }

}

