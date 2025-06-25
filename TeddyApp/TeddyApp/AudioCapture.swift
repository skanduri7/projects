import AVFoundation
import Speech

final class AudioCapture {

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private let engine     = AVAudioEngine()
    
    private var isRecording = false   // accessed only on main queue

    /// Records ≤ `maxSeconds`, stops at silence, returns final transcript (empty if none).
    func transcribe(maxSeconds: TimeInterval = 10) async throws -> String {
        

        // 🔐 0. Run-time mic permission
        guard try await AVCaptureDevice.requestAccess(for: .audio) else {
            throw NSError(domain: "Teddy", code: 2,
                          userInfo:[NSLocalizedDescriptionKey:"Mic permission denied"])
        }

        // 🗣️ 1. Prepare request (NO requiresOnDevice flag → allow fallback)
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = false

        // 🎙️ 2. Start the engine & install a tap
        let bus = 0
        let fmt = engine.inputNode.outputFormat(forBus: bus)
        engine.inputNode.removeTap(onBus: bus)                  // safety
        engine.inputNode.installTap(onBus: bus,
                                    bufferSize: 1024,
                                    format: fmt) { buf, _ in
            req.append(buf)
        }
        try engine.start()

        // ⏳ 3. Return via continuation (resume exactly once)
        return try await withCheckedThrowingContinuation { cont in
            func finish(_ text: String?, _ err: Error? = nil) {
                engine.stop(); engine.inputNode.removeTap(onBus: bus)
                if let err { cont.resume(throwing: err) }
                else      { cont.resume(returning: text ?? "") }
            }

            // timeout guard
            DispatchQueue.main.asyncAfter(deadline: .now() + maxSeconds) {
                finish("")
            }

            // start recognition
            _ = recognizer.recognitionTask(with: req) { res, err in
                if let err = err as? NSError, err.code == 1110 {   // “no speech detected”
                    finish("")
                } else if let err {
                    finish(nil, err)
                } else if let res, res.isFinal {
                    finish(res.bestTranscription.formattedString)
                }
            }
        }
    }
}

