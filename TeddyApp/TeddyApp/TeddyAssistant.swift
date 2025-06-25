//
//  TeddyAssistant.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//
import Foundation
import AppKit  // for notifications, overlays, etc.

final class TeddyAssistant {
    static let shared = TeddyAssistant()
    private init() {}

    /// called when wake-word fires

    private func dialogueLoop() async {
        // 1. record user speech (or read clipboard)
        // 2. build prompt with ScreenContext.describe("*", limit: 50)
        // 3. send to LLM (OpenAI, local, etc.)
        // 4. parse JSON tool call or speak back
        NSSound.beep()

            // 2. ***TEMPORARY*** canned reply –
            //    later replace this string with the LLM’s answer
        let reply = """
            Hello!  I’m Teddy.  I can already read your screen and hear you. \
            What would you like me to do?
            """

            // 3. say it
        Speech.speak(reply)
    }
}


