import SwiftUI

struct ContentView: View {
    enum Mode: String, CaseIterable {
        case canvas = "Canvas Only"
        case webcam = "Webcam Overlay"
        case overlay = "Floating Overlay"
    }

    @State private var selectedMode: Mode = .canvas
    @State private var overlayVisible = false
    @StateObject private var tracker = TrackerClient.shared

    var body: some View {
        VStack(spacing: 20) {
            Picker("Mode", selection: $selectedMode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            Divider()

            Group {
                switch selectedMode {
                case .canvas:
                    CanvasView().environmentObject(tracker)
                case .webcam:
                    WebcamOverlayView().environmentObject(tracker)
                case .overlay:
                    if overlayVisible {
                        overlayControlView     // ← same as before
                    } else {
                        overlayLauncherView
                    }
                    //overlayVisible ? overlayControlView : overlayLauncherView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // View to launch the transparent overlay
    var overlayLauncherView: some View {
        VStack(spacing: 10) {
            Text("Click below to show floating overlay window.")
                .foregroundColor(.secondary)
            Button("Show Overlay") {
                TransparentOverlayWindow.shared.show()
                overlayVisible = true
            }
        }
    }

    // View shown after overlay is launched
    var overlayControlView: some View {
        VStack(spacing: 10) {
            Text("Floating overlay is active.")
                .foregroundColor(.green)
            Button("Hide Overlay") {
                TransparentOverlayWindow.shared.hide()
                overlayVisible = false
            }
        }
    }
}
