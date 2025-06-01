// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI

@main
struct AirBoardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("AirBoard Running")
            .font(.largeTitle)
            .padding()
    }
}

