//
//  Overlay.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/24/25.
//
import AppKit

final class Overlay: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)


        self.isOpaque = false
        self.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.5)
        self.level = .screenSaver          // above everything else
        self.ignoresMouseEvents = true     // click-through
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.orderFrontRegardless()
    }
}

