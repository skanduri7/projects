// AirBoard/App/CanvasView.swift
import SwiftUI

struct CanvasView: View {
    var backgroundColor: Color = .black

    @EnvironmentObject private var tracker: TrackerClient
    @StateObject private var canvasState = CanvasState()

    var body: some View {
        GeometryReader { geo in
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
        }
    }

    private func drawStroke(_ stroke: Stroke, in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        guard let first = stroke.points.first else { return }
        path.move(to: transform(point: first, size: size))
        for p in stroke.points.dropFirst() {
            path.addLine(to: transform(point: p, size: size))
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
        CGPoint(
            x: point.x * size.width,
            y: point.y * size.height
        )
    }
}

