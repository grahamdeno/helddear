import AVFoundation
import Speech
import SwiftUI

/// On-device dictation for the one-line fields. Recognition never leaves the phone:
/// if this iPhone can't recognize speech on device, the button does nothing and the keyboard's own mic still works.
@MainActor
final class Dictation: ObservableObject {
    @Published var isListening = false
    private let recognizer = SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start(onText: @escaping (String) -> Void) {
        guard let recognizer, recognizer.supportsOnDeviceRecognition else { return }
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else { return }
                Task { @MainActor in self.begin(recognizer, onText: onText) }
            }
        }
    }

    private func begin(_ recognizer: SFSpeechRecognizer, onText: @escaping (String) -> Void) {
        stop()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        engine.prepare()
        do { try engine.start() } catch { return }
        isListening = true

        task = recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let finished = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                if let text { onText(text) }
                if finished { self.stop() }
            }
        }
    }

    func stop() {
        guard isListening || task != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
