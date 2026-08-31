import Foundation

/// A user-taught speech correction, mirroring the browser app's
/// `{ wrong, correct, domain }` entries stored in localStorage. These are
/// injected into `company_context` exactly like the browser's
/// `getCorrectionsHint()` so the backend behavior is identical.
struct SpeechCorrection: Codable, Identifiable, Equatable {
    var id = UUID()
    var wrong: String
    var correct: String
    var domain: String

    enum CodingKeys: String, CodingKey { case wrong, correct, domain }
}

/// Persists corrections to UserDefaults (JSON), plus import/export helpers.
@MainActor
final class CorrectionStore: ObservableObject {
    @Published private(set) var items: [SpeechCorrection] = []

    private let key = "speechCorrections"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SpeechCorrection].self, from: data)
        else { return }
        items = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(wrong: String, correct: String, domain: String) {
        let w = wrong.trimmingCharacters(in: .whitespaces).lowercased()
        let c = correct.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !c.isEmpty else { return }
        let d = domain.trimmingCharacters(in: .whitespaces)
        items.append(SpeechCorrection(wrong: w, correct: c, domain: d.isEmpty ? "general" : d))
        persist()
    }

    func update(_ item: SpeechCorrection) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
        persist()
    }

    func delete(_ item: SpeechCorrection) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    /// Matches the browser's `getCorrectionsHint()` text appended to company
    /// context. Keeping the exact wording preserves backend behavior.
    func correctionsHint() -> String {
        guard !items.isEmpty else { return "" }
        let lines = items.map { c -> String in
            let tag = c.domain != "general" ? " [\(c.domain)]" : ""
            return "- \"\(c.wrong)\" means \"\(c.correct)\"\(tag)"
        }
        return "\n\nUser-taught speech corrections (ALWAYS apply these when interpreting transcript):\n"
            + lines.joined(separator: "\n")
    }

    // MARK: - Import / Export

    func exportJSON() -> Data? {
        try? JSONEncoder().encode(items)
    }

    func importJSON(_ data: Data) -> Int {
        guard let imported = try? JSONDecoder().decode([SpeechCorrection].self, from: data) else { return 0 }
        var added = 0
        for imp in imported where !items.contains(where: { $0.wrong == imp.wrong && $0.correct == imp.correct }) {
            items.append(SpeechCorrection(wrong: imp.wrong, correct: imp.correct, domain: imp.domain))
            added += 1
        }
        persist()
        return added
    }
}
