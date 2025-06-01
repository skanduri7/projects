// WebcamOverlayView.swift
import SwiftUI

struct WebcamOverlayView: View {
    @StateObject private var cameraModel = CameraModel()            // manages camera
    @EnvironmentObject private var tracker: TrackerClient            // single tracker

    var body: some View {
        ZStack {
            // 1) Live camera feed underneath
            CameraPreview()
                .ignoresSafeArea()
                .zIndex(0)

            // 2) Transparent drawing layer on top
            CanvasView(backgroundColor: .clear)
                .environmentObject(tracker)
                .ignoresSafeArea()
                .zIndex(1)
        }
        .onDisappear {
                    // As soon as this view goes off‐screen, stop the camera
            cameraModel.session.stopRunning()
        }
    }
}

