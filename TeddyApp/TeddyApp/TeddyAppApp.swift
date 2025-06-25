//
//  TeddyAppApp.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/24/25.
//

import SwiftUI

@main
struct TeddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No regular WindowGroup → nothing appears on launch
        Settings {
            EmptyView()             // placeholder, never shown unless user opens Settings
        }
    }
}


final class AppDelegate: NSObject, NSApplicationDelegate {
    var overlays: [Overlay] = []
    let capture = CaptureController()
    let ax       = AXWatcher()
    let wake = WakeWord()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create one transparent overlay per screen
        for screen in NSScreen.screens {
            let overlay = Overlay(screen: screen)
            overlays.append(overlay)
        }
        capture.start()
        ax.start()
        wake.start { TeddyAssistant.shared.activate() }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            let matches = ContextStore.shared.search("\"Save\"")
//            for m in matches {
//                print("🔎", m.role, m.text, "@", m.rect.integral)
//            }
//        }
    }
}
