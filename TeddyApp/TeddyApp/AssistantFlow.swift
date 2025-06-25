//
//  AssistantFlow.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//
import AppKit

extension TeddyAssistant {

    // called by wake-word
    func activate() {
        NSSound.beep()                         // feedback tone
        
        Speech.speak("Yes?", rate: 0.55)

        Task.detached(priority: .userInitiated) {
            do {
                
                let user = try await AudioCapture().transcribe()
                guard !user.isEmpty else { return }

                let ctx  = ScreenContext.describe("*", limit: 50)
                let ans  = try await OpenAI.chat(user: user, context: ctx)

                Speech.speak(ans)
            } catch {
                print("🛑", error)
                Speech.speak("Sorry, I hit an error.")
            }
        }
    }
}


