// AirBoard/Models/Drawable.swift
import SwiftUI

enum SymbolType {
    case circle(center: CGPoint, radius: CGFloat)
    case rectangle(origin: CGPoint, size: CGSize)
    case text(String, center: CGPoint)
}

struct Symbol: Identifiable {
    let id = UUID()
    var type: SymbolType
    var color: Color = .white
    var lineWidth: CGFloat = 2.0
}

struct Stroke: Identifiable, Equatable {
    let id = UUID()
    var rawPoints: [CGPoint] = []
    var smoothedPoints: [CGPoint] = []
    var color: Color = .white
    var lineWidth: CGFloat = 2.0
    
    var points: [CGPoint] { rawPoints }

    static func == (lhs: Stroke, rhs: Stroke) -> Bool {
        lhs.id == rhs.id
    }
}


enum Drawable: Identifiable {
    case stroke(Stroke)
    case symbol(Symbol)

    var id: UUID {
        switch self {
        case .stroke(let s):  return s.id
        case .symbol(let sym): return sym.id
        }
    }
}

