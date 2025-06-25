//
//  WakeWord.swift
//  TeddyApp
//
//  Created by Saaketh Kanduri on 6/25/25.
//
import AVFoundation
import Speech

final class WakeWord : NSObject, SFSpeechRecognizerDelegate {

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private let audioEngine = AVAudioEngine()
    private var request : SFSpeechAudioBufferRecognitionRequest?
    private var task    : SFSpeechRecognitionTask?

    /// Start continuous keyword listening
    func start(phrase: String = "hey teddy", handler: @escaping () -> Void) {
        
        recognizer.delegate = self

        SFSpeechRecognizer.requestAuthorization { auth in
            guard auth == .authorized else { print("🔴 Speech auth denied"); return }
            
            print("🎙️  SFSpeech auth =", auth == .authorized,
                  "  Mic auth pending…")

            // NEW — ask for microphone access
            AVCaptureDevice.requestAccess(for: .audio) { micOK in
                guard micOK else { print("🔴 Mic auth denied"); return }

                DispatchQueue.main.async {
                    self.startEngine(keyword: phrase.lowercased(), fire: handler)
                }
            }
        }
    }

    // MARK: - private
    private func startEngine(keyword: String, fire: @escaping () -> Void) {
        let input = audioEngine.inputNode
        let fmt   = input.outputFormat(forBus: 0)

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in
            self.request?.append(buf)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        task = recognizer.recognitionTask(with: request!) { result, err in
            guard err == nil, let result = result else { return }

            let phrase = result.bestTranscription.formattedString.lowercased()
            if phrase.contains(keyword) {
                print("🛎️  Wake word detected →", phrase)
                //self.restart()              // reset stream so we don't re-fire
                fire()
            }
        }
        print("🎙️  Wake-word listener running…")
    }

    /// stop + restart to clear recogniser state
    private func restart() {
        task?.cancel()
        task = nil
        request = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // restart after short pause to avoid immediate re-trigger
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.start(phrase: "hey teddy", handler: TeddyAssistant.shared.activate)
        }
    }

    // keep listening if recogniser loses connectivity
    func speechRecognizer(_ s: SFSpeechRecognizer, availabilityDidChange avail: Bool) {
        if !avail { restart() }
    }
}

