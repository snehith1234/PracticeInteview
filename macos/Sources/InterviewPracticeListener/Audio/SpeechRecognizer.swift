import Foundation
import AVFoundation
import Speech
import AppKit

/// Native macOS replacement for the browser's `webkitSpeechRecognition`.
///
/// The browser API does not exist outside Chromium, so this is the one place
/// where a browser-only dependency is replaced (per the plan). The BEHAVIOR is
/// kept the same as the React app:
///   Start Listening -> capture mic -> partial transcript -> 2s silence
///   -> emit "question complete" -> keep listening for the next question.
///
/// Duplicate-submission is guarded by the view model (which pauses us while an
/// answer is generating), mirroring the browser's `isGeneratingRef`.
@MainActor
final class SpeechRecognizer: ObservableObject {

    @Published private(set) var transcript: String = ""
    @Published private(set) var partial: String = ""
    @Published private(set) var isListening: Bool = false
    @Published private(set) var permissionError: String?

    /// Called when 2s of silence follows speech, with the final transcript.
    var onSilenceComplete: ((String) -> Void)?

    /// Silence window (default 2.0s = SILENCE_TIMEOUT_MS from the browser app).
    var silenceTimeout: TimeInterval = 2.0

    /// Whether auto-submit on silence is enabled (browser "Auto on silence").
    var autoOnSilence: Bool = true

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var lastSpeechAt: Date?
    private var silenceTimer: Timer?
    private var manuallyStopped = false

    // MARK: - Permissions

    /// Requests Speech + Microphone permissions. Returns true only if both
    /// granted. Sets `permissionError` with an actionable message otherwise.
    func requestPermissions() async -> Bool {
        // Bring the app to the foreground so macOS can present the TCC
        // permission dialogs (an accessory / non-activating app otherwise fails
        // to surface the mic/speech prompts, leaving status .notDetermined).
        await MainActor.run {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speechOK else {
            permissionError = "Speech recognition permission required. Enable it in System Settings › Privacy & Security › Speech Recognition."
            return false
        }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        guard micOK else {
            permissionError = "Microphone permission required. Enable it in System Settings › Privacy & Security › Microphone."
            return false
        }
        permissionError = nil
        return true
    }

    // MARK: - Start / Stop

    func start() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            permissionError = "Speech recognizer is not available right now."
            return
        }
        manuallyStopped = false
        transcript = ""
        partial = ""
        lastSpeechAt = nil
        do {
            try beginSession()
            isListening = true
            permissionError = nil
        } catch {
            permissionError = "Could not start microphone: \(error.localizedDescription)"
            isListening = false
        }
    }

    func stop() {
        manuallyStopped = true
        teardown()
        isListening = false
    }

    /// Pause while an answer is generating (prevents duplicate submissions).
    /// Sets `manuallyStopped` so the recognition task's teardown error does NOT
    /// trigger an auto-restart (which previously kept the mic alive and made
    /// answers regenerate on their own).
    func pauseForGeneration() {
        manuallyStopped = true
        teardown()
        isListening = false
    }

    func clearTranscript() {
        transcript = ""
        partial = ""
        lastSpeechAt = nil
    }

    // MARK: - Session

    private func beginSession() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        // Reset the engine so a stale/invalid input-node configuration from a
        // previous session doesn't linger (also helps right after the mic
        // permission is first granted).
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.reset()

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        // Read the input node's real hardware format.
        let nodeFormat = inputNode.outputFormat(forBus: 0)
        guard nodeFormat.sampleRate > 0, nodeFormat.channelCount > 0 else {
            throw NSError(domain: "IPL", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No usable microphone input was found. Check the input device in System Settings › Sound."
            ])
        }

        // Install the capture tap using the node's native format (nil lets
        // AVAudioEngine use the input node's own format with no conversion
        // mismatch — a common cause of kAUStartIO failures on macOS).
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in self?.handleRecognition(result: result, error: error) }
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            partial = result.bestTranscription.formattedString
            markSpeech()
            if result.isFinal { appendFinal(partial) }
        }
        if error != nil, !manuallyStopped {
            // Recognition restart / timeout — auto-restart like the browser's
            // recog.onend handler does.
            restart()
        }
    }

    private func appendFinal(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if transcript.isEmpty {
            transcript = trimmed
        } else if !transcript.contains(trimmed) {
            transcript += " " + trimmed
        }
        partial = ""
    }

    private func restart() {
        teardown()
        guard !manuallyStopped else { return }
        do { try beginSession() }
        catch {
            permissionError = "Could not restart microphone: \(error.localizedDescription)"
            isListening = false
        }
    }

    private func teardown() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    // MARK: - Silence detection (2s, matches browser)

    private func markSpeech() {
        lastSpeechAt = Date()
        startSilenceCheck()
    }

    private func startSilenceCheck() {
        guard autoOnSilence, silenceTimer == nil else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSilence() }
        }
    }

    private func checkSilence() {
        guard let last = lastSpeechAt else { return }
        guard Date().timeIntervalSince(last) >= silenceTimeout else { return }
        silenceTimer?.invalidate()
        silenceTimer = nil
        if !partial.isEmpty { appendFinal(partial) }
        let finalTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalTranscript.isEmpty else { return }
        onSilenceComplete?(finalTranscript)
    }
}
