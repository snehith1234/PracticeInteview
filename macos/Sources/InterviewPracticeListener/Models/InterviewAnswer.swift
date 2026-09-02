import Foundation

/// The answer sections produced by the EXISTING backend, mapped 1:1 from the
/// markdown headings returned by `/coach/quick-answer`:
///   # Detected Question
///   # 30-Second Version
///   # Real-Time Example
///   # Strong Answer
///   # Key Points to Mention
///   # Possible Follow-Up Questions
///   # Follow-Up Answer Hints
/// plus the "Say This Now" text from `/coach/quick-short`.
///
/// This model does NOT change how answers are generated. It only holds the
/// existing output for display in the native UI.
struct InterviewAnswer: Identifiable, Equatable {
    let id = UUID()

    var question: String = ""

    /// "Say This Now" — arrives first (from /coach/quick-short).
    var quickAnswer: String = ""

    var thirtySecond: String = ""
    var realTimeExample: String = ""
    var strongAnswer: String = ""

    /// # Code — only populated for coding questions (fenced code + complexity).
    var code: String = ""

    /// # Diagram — only populated when a visual (ASCII flow/box) adds clarity.
    var diagram: String = ""

    var keyPoints: String = ""
    var followUpQuestions: String = ""
    var followUpHints: String = ""

    /// Full raw markdown of the second (full) response, kept for history export
    /// parity with the browser app which stores the full text.
    var fullRawMarkdown: String = ""

    var createdAt: Date = Date()

    var isEmpty: Bool {
        quickAnswer.isEmpty && thirtySecond.isEmpty && realTimeExample.isEmpty
            && strongAnswer.isEmpty
    }
}

/// Per-section loading flags so the UI can show subtle progressive states,
/// mirroring the browser's two-phase display (quick first, then full).
struct AnswerLoadingState: Equatable {
    var quickAnswerLoading = false
    var fullAnswerLoading = false

    var isIdle: Bool { !quickAnswerLoading && !fullAnswerLoading }
}

/// High-level app state shown as the status dot in the header.
enum ListeningState: Equatable {
    case idle
    case listening
    case processing
    case paused
    case backendOffline
    case micPermissionRequired
    case speechPermissionRequired
    case error(String)

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .listening: return "Listening"
        case .processing: return "Processing"
        case .paused: return "Paused"
        case .backendOffline: return "Backend Offline"
        case .micPermissionRequired: return "Microphone Permission Required"
        case .speechPermissionRequired: return "Speech Permission Required"
        case .error(let msg): return msg
        }
    }
}
