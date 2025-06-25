//
//  Speech.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//


import AVFoundation

enum Speech {

    private static let synth = AVSpeechSynthesizer()

    /// Speak `text` once, interrupting any previous utterance.
    static func speak(_ text: String, rate: Float = 0.45) {
        DispatchQueue.main.async {
            if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

            let utt = AVSpeechUtterance(string: text)
            utt.voice = AVSpeechSynthesisVoice(language: "en-US")
            utt.rate  = rate                          // 0.0 … 1.0 (default ≈ 0.5)
            synth.speak(utt)
        }
    }
}

