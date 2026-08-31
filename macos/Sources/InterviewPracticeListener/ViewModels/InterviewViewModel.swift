import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Orchestrates the SAME two-phase flow the browser `twoPhaseAnswer` uses:
///   1) POST /coach/quick-short  -> "Say This Now" (quick answer)
///   2) POST /coach/quick-answer with {quick_answer} -> full sections
/// No generation logic is changed here; this only drives the existing endpoints
/// and maps their output into the UI model.
@MainActor
final class InterviewViewModel: ObservableObject {

    @Published var answer = InterviewAnswer()
    @Published var loadingState = AnswerLoadingState()
    @Published var listeningState: ListeningState = .idle
    @Published var statusMessage: String = ""
    @Published var history: [InterviewAnswer] = []

    @Published var liveTranscript: String = ""
    @Published var isCompact: Bool = false

    /// Detected-question metadata (type · topic · difficulty) from the
    /// standalone Detect Question action.
    @Published var detected: DetectResponse?

    /// Feedback from Evaluate My Answer.
    @Published var evaluationFeedback: String = ""
    @Published var isEvaluating = false

    /// Last screenshot capture: extracted text + saved image path.
    @Published var screenshotText: String = ""
    @Published var screenshotPath: String = ""
    @Published var isCapturing = false

    let settings: AppSettings
    let speech = SpeechRecognizer()
    let corrections = CorrectionStore()
    private let api = APIClient()

    /// Mirrors the browser `isGeneratingRef` duplicate-submission guard.
    private var isGenerating = false
    private var profile: [String: AnyCodable] = [:]

    /// Company context + speech-correction hint, matching the browser's
    /// `(companyContext || '') + getCorrectionsHint()` behavior.
    private var companyContextWithCorrections: String {
        settings.companyContext + corrections.correctionsHint()
    }

    init(settings: AppSettings) {
        self.settings = settings
        self.isCompact = settings.compactByDefault
        self.speech.silenceTimeout = settings.silenceTimeout
        self.speech.autoOnSilence = settings.autoOnSilence

        speech.onSilenceComplete = { [weak self] transcript in
            Task { @MainActor in await self?.handleSilenceComplete(transcript) }
        }

        // Reflect live transcript into the UI.
        observeSpeech()
    }

    private func observeSpeech() {
        // Simple polling-free bridge: update liveTranscript whenever speech
        // publishes. Using a Combine-free approach with a timer would poll, so
        // instead we read speech.transcript in the views via @ObservedObject.
    }

    // MARK: - Listening controls

    func toggleListening() async {
        if speech.isListening { await stopListeningAndGenerate() }
        else { await startListening() }
    }

    func startListening() async {
        let ok = await speech.requestPermissions()
        guard ok else {
            if let err = speech.permissionError {
                listeningState = err.contains("Microphone") ? .micPermissionRequired : .speechPermissionRequired
                statusMessage = err
            }
            return
        }
        speech.silenceTimeout = settings.silenceTimeout
        speech.autoOnSilence = settings.autoOnSilence
        speech.start()
        if speech.isListening {
            listeningState = .listening
            statusMessage = "Listening… (auto-generates after silence)"
        } else if let err = speech.permissionError {
            statusMessage = err
        }
    }

    func stopListeningAndGenerate() async {
        speech.stop()
        listeningState = .idle
        let transcript = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isGenerating, !transcript.isEmpty {
            await twoPhaseAnswer(transcript)
        }
    }

    private func handleSilenceComplete(_ transcript: String) async {
        guard !isGenerating else { return }
        // Stop mic while generating (browser stops recognition on auto-trigger).
        speech.pauseForGeneration()
        listeningState = .processing
        statusMessage = "Silence detected — generating answer…"
        await twoPhaseAnswer(transcript)
    }

    // MARK: - Two-phase answer (mirrors browser twoPhaseAnswer)

    func twoPhaseAnswer(_ transcript: String) async {
        guard !transcript.isEmpty else {
            statusMessage = APIError.emptyTranscript.localizedDescription
            return
        }
        isGenerating = true
        defer { isGenerating = false }

        // Reset current answer, keep history.
        answer = InterviewAnswer()
        listeningState = .processing

        let baseBody = QuickAnswerRequest(
            role: settings.role,
            job_description: settings.jobDescription,
            resume_text: settings.resumeText,
            company_context: companyContextWithCorrections,
            additional_context: settings.additionalContext,
            profile: profile,
            transcript: transcript,
            quick_answer: "",
            mode: "practice",
            model: settings.model
        )

        // Phase 1: /coach/quick-short  -> "Say This Now"
        // NOTE: the browser passes the RAW phase-1 SSE text (including the
        // "**Q:** ... **A:** ..." markup) as `quick_answer` to phase 2. We do
        // the same so the backend receives an identical request. For display we
        // show only the extracted answer portion.
        loadingState.quickAnswerLoading = true
        var quickRaw = ""
        do {
            let body = try JSONEncoder().encode(baseBody)
            quickRaw = try await api.streamSSE(
                baseURL: settings.backendURL, path: "/coach/quick-short",
                body: body, apiKey: settings.apiKey
            ) { [weak self] accumulated in
                Task { @MainActor in
                    self?.answer.quickAnswer = AnswerParser.extractQuickAnswer(from: accumulated)
                    if let q = AnswerParser.extractQuickQuestion(from: accumulated), !q.isEmpty {
                        self?.answer.question = q
                    }
                }
            }
        } catch {
            reportError(error)
        }
        loadingState.quickAnswerLoading = false

        // Phase 2: /coach/quick-answer with quick_answer -> full sections
        loadingState.fullAnswerLoading = true
        var fullBody = baseBody
        fullBody.quick_answer = quickRaw   // raw text, exactly like the browser
        do {
            let body = try JSONEncoder().encode(fullBody)
            let full = try await api.streamSSE(
                baseURL: settings.backendURL, path: "/coach/quick-answer",
                body: body, apiKey: settings.apiKey
            ) { [weak self] accumulated in
                Task { @MainActor in
                    guard var current = self?.answer else { return }
                    AnswerParser.merge(into: &current, fullMarkdown: accumulated)
                    self?.answer = current
                }
            }
            AnswerParser.merge(into: &answer, fullMarkdown: full)
            statusMessage = ""
            // Match the browser: detected question from "# Detected Question",
            // falling back to "From transcript" for the history entry.
            if !full.isEmpty {
                if answer.question.isEmpty {
                    answer.question = "From transcript"
                }
                history.insert(answer, at: 0)
            }
        } catch {
            reportError(error)
        }
        loadingState.fullAnswerLoading = false
        listeningState = .idle

        // Clear transcript for the next question (browser clears it too).
        speech.clearTranscript()
        liveTranscript = ""
    }

    // MARK: - Manual question submission (browser "Generate Practice Answer")

    func generateFromManualTranscript(_ text: String) async {
        guard !isGenerating else { return }
        speech.pauseForGeneration()
        await twoPhaseAnswer(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Context: profile + uploads

    func analyzeProfile() async {
        statusMessage = "Analyzing resume + JD…"
        let req = ProfileRequest(
            role: settings.role, job_description: settings.jobDescription,
            resume_text: settings.resumeText, company_context: settings.companyContext,
            additional_context: settings.additionalContext, model: settings.model
        )
        do {
            let dict = try await api.postJSON(
                baseURL: settings.backendURL, path: "/coach/profile",
                body: req, apiKey: settings.apiKey, as: [String: AnyCodable].self
            )
            profile = dict
            statusMessage = "Candidate profile created."
        } catch {
            reportError(error)
        }
    }

    func uploadResume(_ url: URL) async {
        await upload(url, path: "/upload/resume") { [weak self] text in
            self?.settings.resumeText = text
        }
    }

    func uploadContext(_ url: URL) async {
        await upload(url, path: "/upload/context") { [weak self] text in
            let prev = self?.settings.additionalContext ?? ""
            self?.settings.additionalContext = prev.isEmpty ? text : prev + "\n\n" + text
        }
    }

    private func upload(_ url: URL, path: String, assign: @escaping (String) -> Void) async {
        statusMessage = "Uploading \(url.lastPathComponent)…"
        do {
            let resp = try await api.uploadFile(baseURL: settings.backendURL, path: path, fileURL: url)
            assign(resp.text)
            statusMessage = "Parsed \(resp.characters) characters."
        } catch {
            reportError(error)
        }
    }

    // MARK: - Test / health

    func testBackend() async {
        let up = await api.healthCheck(baseURL: settings.backendURL)
        if !up {
            listeningState = .backendOffline
            statusMessage = APIError.backendOffline.localizedDescription
            return
        }
        do {
            let resp = try await api.postJSON(
                baseURL: settings.backendURL, path: "/coach/test-llm",
                body: TestRequest(model: settings.model), apiKey: settings.apiKey,
                as: TestLLMResponse.self
            )
            statusMessage = resp.ok ? "✅ \(resp.message ?? "Model OK")" : "❌ \(resp.error ?? "Model error")"
        } catch {
            reportError(error)
        }
    }

    // MARK: - Detect Question (standalone, /coach/detect-question)

    func detectQuestion() async {
        let transcript = (liveTranscript.isEmpty ? speech.transcript : liveTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let source = transcript.isEmpty ? speech.transcript : transcript
        guard !source.trimmingCharacters(in: .whitespaces).isEmpty else {
            statusMessage = "Nothing to detect yet — speak or type a transcript first."
            return
        }
        statusMessage = "Detecting latest question…"
        do {
            let resp = try await api.postJSON(
                baseURL: settings.backendURL, path: "/coach/detect-question",
                body: DetectRequest(transcript: source, model: settings.model),
                apiKey: settings.apiKey, as: DetectResponse.self
            )
            detected = resp
            if let q = resp.clean_question, !q.isEmpty { answer.question = q }
            statusMessage = (resp.is_interview_question ?? false)
                ? "Question detected." : "No clear interview question detected."
        } catch {
            reportError(error)
        }
    }

    // MARK: - Evaluate My Answer (/coach/evaluate)

    func evaluate(question: String, userAnswer: String) async {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else {
            statusMessage = "Question and your answer are required for feedback."
            return
        }
        isEvaluating = true
        evaluationFeedback = ""
        defer { isEvaluating = false }
        do {
            let resp = try await api.postJSON(
                baseURL: settings.backendURL, path: "/coach/evaluate",
                body: EvaluateRequest(role: settings.role, job_description: settings.jobDescription,
                                      profile: profile, question: q, user_answer: a, model: settings.model),
                apiKey: settings.apiKey, as: EvaluateResponse.self
            )
            evaluationFeedback = resp.feedback
        } catch {
            reportError(error)
        }
    }

    // MARK: - Screenshot + OCR

    /// Callback set by the window controller to hide/show the panel so our own
    /// window isn't in the full-screen shot.
    var hidePanelForCapture: (() -> Void)?
    var showPanelAfterCapture: (() -> Void)?

    func captureScreenshot() async {
        guard !isCapturing else { return }
        isCapturing = true
        statusMessage = "Capturing screen…"

        // Hide our floating window so it isn't in the screenshot.
        hidePanelForCapture?()
        // Give the compositor a moment to actually hide the window.
        try? await Task.sleep(nanoseconds: 350_000_000)

        defer {
            showPanelAfterCapture?()
            isCapturing = false
        }

        do {
            let result = try await ScreenCapture.captureFullScreenAndOCR()
            screenshotPath = result.imageURL.path
            screenshotText = result.text
            statusMessage = result.text.isEmpty
                ? "Screenshot saved (no text found): \(result.imageURL.lastPathComponent)"
                : "Screenshot saved & text extracted: \(result.imageURL.lastPathComponent)"
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Use the OCR text as the transcript and generate an answer.
    func generateFromScreenshotText() async {
        let text = screenshotText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "No extracted text to use."
            return
        }
        await generateFromManualTranscript(text)
    }

    // MARK: - Teach a speech correction (from the 👎 flow)

    func teachCorrection(wrong: String, correct: String, domain: String) {
        corrections.add(wrong: wrong, correct: correct, domain: domain)
        statusMessage = "Learned: \"\(wrong)\" → \"\(correct)\""
    }

    // MARK: - History export (browser "Download Q&A History")

    func historyMarkdown() -> String {
        history.enumerated().map { idx, h in
            let n = history.count - idx
            let body = h.fullRawMarkdown.isEmpty
                ? "SAY THIS NOW\n\(h.quickAnswer)" : h.fullRawMarkdown
            return "# Question \(n)\n\(h.question)\n\n\(body)\n"
        }.joined(separator: "\n---\n")
    }

    func clearAnswer() {
        answer = InterviewAnswer()
        detected = nil
        statusMessage = ""
    }

    private func reportError(_ error: Error) {
        let message = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        if case .backendOffline = (error as? APIError) {
            listeningState = .backendOffline
        } else {
            listeningState = .error(message)
        }
        statusMessage = message
    }
}
