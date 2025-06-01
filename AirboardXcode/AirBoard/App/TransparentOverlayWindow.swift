import AppKit
import SwiftUI

/// A borderless, full‐screen, transparent window that hosts a `CanvasView`
/// with a clear background so you can draw “on air.”
class TransparentOverlayWindow: NSWindowController {
    /// Shared singleton instance
    static let shared = TransparentOverlayWindow()

    private init() {
        // Create the CanvasView with a transparent background
        let canvasView = CanvasView(backgroundColor: .clear).environmentObject(TrackerClient.shared)
        let hostingController = NSHostingController(rootView: canvasView)

        // Use the main screen’s frame (full screen)
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window to float above everything, be transparent, and accept clicks
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.ignoresMouseEvents = false    // Allow drawing interactions
        window.hasShadow = false
        window.collectionBehavior = [
            .canJoinAllSpaces,                // Show on all Spaces
            .fullScreenAuxiliary              // Work alongside fullscreen apps
        ]

        // Host the SwiftUI canvas inside the window
        window.contentView = hostingController.view

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Show the transparent overlay window
    func show() {
        window?.makeKeyAndOrderFront(nil)
    }

    /// Hide the transparent overlay window
    func hide() {
        window?.orderOut(nil)
    }
}

