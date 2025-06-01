// AirBoard/App/CanvasView.swift
import SwiftUI

struct CanvasView: View {
    var backgroundColor: Color = .black

    @EnvironmentObject private var tracker: TrackerClient
    @StateObject private var canvasState = CanvasState()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                backgroundColor.ignoresSafeArea()

                Canvas { context, size in
                    // Draw all committed drawables
                    for drawable in canvasState.drawables {
                        switch drawable {
                        case .stroke(let stroke):
                            drawStroke(stroke, in: &context, size: size)
                        case .symbol(let symbol):
                            drawSymbol(symbol, in: &context, size: size)
                        }
                    }
                    // Draw the current in-progress stroke (if any)
                    if let current = canvasState.currentStroke {
                        drawStroke(current, in: &context, size: size)
                    }
                }
                // No gestures needed: we handle penDown/up via tracker subscriptions
            }
            .onChange(of: tracker.isPenDown) { _, newDown in
                if newDown {
                    // Right-hand just pinched → start a new stroke
                    canvasState.startStroke()
                } else {
                    // Pinch released → end stroke & recognize
                    canvasState.endCurrentStroke()
                }
            }
            .onChange(of: tracker.fingertipPosition) { _, newPos in
                // Only add points while pinched
                guard tracker.isPenDown else { return }
                canvasState.addPointToCurrentStroke(newPos)
            }
            .onChange(of: tracker.leftHandPinchDistance) { _, pinch in
                canvasState.updateCameraZoom(
                    pinch: pinch,
                    at: tracker.leftHandPosition,
                    canvasSize: size
                )
            }
        }
    }

    private func drawStroke(_ stroke: Stroke, in context: inout GraphicsContext, size: CGSize) {
        let pts = stroke.smoothedPoints
        guard pts.count > 1 else { return }
        
        var path = Path()
        let first = transform(point: pts[0], size: size)
        path.move(to: first)
        
        if pts.count == 2 {
            let second = transform(point: pts[1], size: size)
            path.addLine(to: second)
            context.stroke(path, with: .color(stroke.color), lineWidth: stroke.lineWidth)
            return
        }
        
        let tension: CGFloat = 0.5

        for i in 0 ..< (pts.count - 1) {
            let p1 = pts[i]
            let p2 = pts[i + 1]
            // p0 (previous node) = either pts[i-1] or p1 again if i==0
            let p0 = (i == 0) ? p1 : pts[i - 1]
            // p3 (next node) = either pts[i+2], or p2 again if i+2 out of bounds
            let p3 = (i + 2 < pts.count) ? pts[i + 2] : p2

            // compute control points:
            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * tension / 3.0,
                y: p1.y + (p2.y - p0.y) * tension / 3.0
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * tension / 3.0,
                y: p2.y - (p3.y - p1.y) * tension / 3.0
            )

            // transform to pixel space:
            let tP2 = transform(point: p2, size: size)
            let tC1 = transform(point: c1, size: size)
            let tC2 = transform(point: c2, size: size)

            // draw one cubic Bézier segment from current “cursor”→p2
            path.addCurve(to: tP2, control1: tC1, control2: tC2)
        }

        context.stroke(path, with: .color(stroke.color), lineWidth: stroke.lineWidth)
        
    }

    private func drawSymbol(_ symbol: Symbol, in context: inout GraphicsContext, size: CGSize) {
        switch symbol.type {
        case .circle(let center, let radius):
            let pixelCenter = transform(point: center, size: size)
            let pixelRadius = radius * size.width
            let rect = CGRect(
                x: pixelCenter.x - pixelRadius,
                y: pixelCenter.y - pixelRadius,
                width: pixelRadius * 2,
                height: pixelRadius * 2
            )
            context.stroke(Path(ellipseIn: rect),
                           with: .color(symbol.color),
                           lineWidth: symbol.lineWidth)

        case .rectangle(let origin, let sz):
            let pixelOrigin = transform(point: origin, size: size)
            let pixelSize = CGSize(width: sz.width * size.width,
                                   height: sz.height * size.height)
            let rect = CGRect(origin: pixelOrigin, size: pixelSize)
            context.stroke(Path(rect),
                           with: .color(symbol.color),
                           lineWidth: symbol.lineWidth)

        case .text(let str, let center):
            let pixelCenter = transform(point: center, size: size)
            let textView = Text(str)
                            .font(.system(size: size.width * 0.1, weight: .bold, design: .monospaced))
                            .foregroundColor(symbol.color)
            context.draw(textView, at: pixelCenter, anchor: .center)
        }
    }

    private func transform(point: CGPoint, size: CGSize) -> CGPoint {
        let scaled = CGPoint(
            x: point.x * size.width * canvasState.cameraScale,
            y: point.y * size.height * canvasState.cameraScale
        )
        return CGPoint(
            x: scaled.x + canvasState.cameraOffset.width,
            y: scaled.y + canvasState.cameraOffset.height
        )
    }
}

