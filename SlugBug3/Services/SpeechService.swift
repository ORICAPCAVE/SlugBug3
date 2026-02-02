import Foundation
import Combine
import AVFAudio
import Speech

final class SpeechService: NSObject, ObservableObject {

    // MARK: - Published state for UI
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var isRecording: Bool = false
    @Published var transcript: String = ""

    // MARK: - Audio/Speech internals
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Auto-restart gate + backoff
    private var shouldAutoRestart = false
    private var retryDelay: TimeInterval = 0.5

    // MARK: - Public API expected by your View
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async { self?.authorizationStatus = status }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }

    // Call this to START listening (arms auto-restart)
    func beginListening() throws {
        shouldAutoRestart = true
        try startRecording()
    }

    // Call this to STOP listening (disarms auto-restart)
    func endListening() {
        shouldAutoRestart = false
        stopRecording()
    }

    func startRecording() throws {
        guard !isRecording else { return }
        transcript = ""

        // 1) Ensure speech is available
        guard speechRecognizer?.isAvailable == true else {
            throw NSError(domain: "SpeechService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available — try again."])
        }

        // 2) Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // 3) Create a fresh request & task
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        // Bias the decoder toward our keywords
        recognitionRequest?.contextualStrings = ["bug", "buggy", "slug", "slugbug"]

        if #available(iOS 13.0, *),
           let r = speechRecognizer, r.supportsOnDeviceRecognition {
            recognitionRequest?.requiresOnDeviceRecognition = true // remove if you prefer cloud fallback
        }

        if #available(iOS 13.0, *) {
            recognitionRequest?.taskHint = .dictation // helps reduce spurious endpointing
        }

        guard let request = recognitionRequest else {
            throw NSError(
                domain: "SpeechService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"]
            )
        }


        // 4) Wire recognition task (guarded restarts)
        retryDelay = 0.5
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                print("Partial:", text)
                if let seg = result.bestTranscription.segments.last {
                    print("Last word:", seg.substring, "conf:", seg.confidence)
                }
                DispatchQueue.main.async { self.transcript = text }

                if result.isFinal {
                    self.stopAudioOnly()
                    guard self.shouldAutoRestart else { self.stopRecording(); return }
                    self.retryDelay = 0.5
                    try? self.startRecording()
                    return
                }
            }

            if let e = error as NSError? {
                // If we already produced text this pass, 216 is usually just endpointing.
                let code = e.code
                let isAssistant = (e.domain == "kAFAssistantErrorDomain")

                // Log once (optional)
                print("Speech error:", e.domain, code, e.localizedDescription)

                // Always stop current audio stream cleanly
                self.stopAudioOnly()

                // Decide what to do next
                if self.shouldAutoRestart {
                    // Treat common transient codes as "ok to retry"
                    if isAssistant && (code == 203 || code == 216) {
                        self.retryDelay = 0.5 // reset backoff for benign cases
                    } else {
                        self.retryDelay = min(self.retryDelay * 2, 8.0) // backoff for real errors
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                        try? self.startRecording()
                    }
                } else {
                    // If not armed, fully stop
                    self.stopRecording()
                }
                return
            }

        }

        // 5) Install tap with a valid format
        let input = audioEngine.inputNode
        let format = input.inputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // 6) Start the engine
        audioEngine.prepare()
        try audioEngine.start()
        DispatchQueue.main.async { self.isRecording = true }

        print("Auth:", authorizationStatus.rawValue,
              "Recognizer available:", speechRecognizer?.isAvailable ?? false,
              "Engine running:", audioEngine.isRunning)
    }

    // FULL stop: cancels task & deactivates session
    private func stopRecording() {
        guard isRecording || recognitionTask != nil else { return }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DispatchQueue.main.async { self.isRecording = false }
    }

    // Soft stop used for continuous restarts
    private func stopAudioOnly() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
}
