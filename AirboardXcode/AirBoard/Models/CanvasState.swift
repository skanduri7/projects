// AirBoard/Models/CanvasState.swift
import SwiftUI
import Combine
import Vision
import AppKit

final class CanvasState: ObservableObject {
    @Published var drawables: [Drawable] = []
    @Published var currentStroke: Stroke? = nil

    // Begin a new stroke when pen-down
    func startStroke(color: Color = .white, lineWidth: CGFloat = 2.0) {
        currentStroke = Stroke(color: color, lineWidth: lineWidth)
    }

    // Add points while pen is down
    func addPointToCurrentStroke(_ point: CGPoint) {
        guard var stroke = currentStroke else { return }
        stroke.addPoint(point)
        currentStroke = stroke
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
        if let (center, radius) = Self.isCircle(points: stroke.points) {
            let symbol = Symbol(type: .circle(center: center, radius: radius),
                                color: stroke.color,
                                lineWidth: stroke.lineWidth)
            drawables.append(.symbol(symbol))
            return
        }

        // 3) Try rectangle
        if let (origin, size) = Self.isRectangle(points: stroke.points) {
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
        let size = CGSize(width: 1024, height: 1024)

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
        cgContext.setLineWidth(4.0)
        cgContext.setLineCap(.round)

        // 5) Map each normalized point [0…1] → pixel [0…256], flipping Y
        let pts: [CGPoint] = stroke.points.map { p in
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
        guard points.count > 5 else { return nil }
        let xs = points.map { $0.x }, ys = points.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let origin = CGPoint(x: minX, y: minY)
        let size = CGSize(width: maxX - minX, height: maxY - minY)

        let tolX = size.width * 0.1, tolY = size.height * 0.1
        let nearEdgeCount = points.filter { p in
            let onLeft   = abs(p.x - minX) < tolX
            let onRight  = abs(p.x - maxX) < tolX
            let onTop    = abs(p.y - maxY) < tolY
            let onBottom = abs(p.y - minY) < tolY
            return onLeft || onRight || onTop || onBottom
        }.count

        if CGFloat(nearEdgeCount) / CGFloat(points.count) > 0.8 {
            return (origin, size)
        }
        return nil
    }
}

