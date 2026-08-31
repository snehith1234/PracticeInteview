import Foundation

/// Parses the streamed markdown from the EXISTING backend into structured
/// sections. Must stay in sync with the headings emitted by
/// `coach_service.detect_and_answer_stream` (do not change those headings —
/// this only reads them):
///
///   # Detected Question
///   # 30-Second Version
///   # Real-Time Example
///   # Strong Answer
///   # Key Points to Mention
///   # Possible Follow-Up Questions
///   # Follow-Up Answer Hints
///
/// Tolerant of partial text during streaming: a trailing incomplete section is
/// still assigned to its heading so the UI can populate progressively.
enum AnswerParser {

    enum SectionKey {
        case question
        case thirtySecond
        case realTimeExample
        case strongAnswer
        case code
        case keyPoints
        case followUpQuestions
        case followUpHints
    }

    private static let headings: [(key: SectionKey, title: String)] = [
        (.question, "detected question"),
        (.thirtySecond, "30-second version"),
        (.realTimeExample, "real-time example"),
        (.strongAnswer, "strong answer"),
        (.code, "code"),
        (.keyPoints, "key points to mention"),
        (.followUpQuestions, "possible follow-up questions"),
        (.followUpHints, "follow-up answer hints"),
    ]

    /// Merge parsed full-answer sections into an existing answer, preserving
    /// the already-streamed quickAnswer.
    static func merge(into answer: inout InterviewAnswer, fullMarkdown: String) {
        answer.fullRawMarkdown = fullMarkdown
        let sections = parse(fullMarkdown)
        if let q = sections[.question], !q.isEmpty { answer.question = q }
        if let s = sections[.thirtySecond] { answer.thirtySecond = s }
        if let s = sections[.realTimeExample] { answer.realTimeExample = s }
        if let s = sections[.strongAnswer] { answer.strongAnswer = s }
        if let s = sections[.code] { answer.code = s }
        if let s = sections[.keyPoints] { answer.keyPoints = s }
        if let s = sections[.followUpQuestions] { answer.followUpQuestions = s }
        if let s = sections[.followUpHints] { answer.followUpHints = s }
    }

    static func parse(_ markdown: String) -> [SectionKey: String] {
        var result: [SectionKey: String] = [:]
        var currentKey: SectionKey?
        var buffer: [String] = []

        func flush() {
            guard let key = currentKey else { return }
            result[key] = buffer.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for line in markdown.components(separatedBy: "\n") {
            if let key = headingKey(for: line) {
                flush()
                currentKey = key
                buffer = []
            } else if currentKey != nil {
                buffer.append(line)
            }
        }
        flush()
        return result
    }

    /// `/coach/quick-short` returns:  **Q:** ...  **A:** ...
    /// Extract just the answer portion for "Say This Now".
    static func extractQuickAnswer(from raw: String) -> String {
        if let range = raw.range(of: "**A:**") {
            return String(raw[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.contains("Q:"), let range = raw.range(of: "A:") {
            return String(raw[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractQuickQuestion(from raw: String) -> String? {
        guard let qRange = raw.range(of: "**Q:**") ?? raw.range(of: "Q:") else { return nil }
        let afterQ = raw[qRange.upperBound...]
        if let aRange = afterQ.range(of: "**A:**") ?? afterQ.range(of: "A:") {
            return String(afterQ[..<aRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(afterQ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func headingKey(for line: String) -> SectionKey? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let title = trimmed.drop(while: { $0 == "#" })
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return headings.first(where: { $0.title == title })?.key
    }
}
