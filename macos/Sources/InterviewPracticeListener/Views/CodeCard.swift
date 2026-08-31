import SwiftUI

/// Renders the "# Code" section for coding questions: the fenced code block in
/// a monospaced, horizontally-scrollable view with a copy button, plus any
/// trailing complexity line (e.g. "Time: O(n) | Space: O(1)").
struct CodeCard: View {
    let raw: String
    let fontSize: Double

    var body: some View {
        let (code, note) = Self.splitCodeAndNote(raw)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CODE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.cyan)
                    .kerning(0.5)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)) }
                .buttonStyle(.borderless)
                .help("Copy code")
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: fontSize, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))

            if !note.isEmpty {
                Text(note)
                    .font(.system(size: fontSize - 1, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cyan.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
        )
    }

    /// Extracts the code inside the first ```lang ... ``` fence (if present) and
    /// returns any non-fence trailing text (e.g. the complexity line) as `note`.
    static func splitCodeAndNote(_ raw: String) -> (code: String, note: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstFence = text.range(of: "```") else {
            return (text, "")
        }
        let afterOpen = text[firstFence.upperBound...]
        guard let closeFence = afterOpen.range(of: "```") else {
            // Unterminated fence (still streaming) — show what we have.
            var body = String(afterOpen)
            if let nl = body.firstIndex(of: "\n") { body = String(body[body.index(after: nl)...]) }
            return (body.trimmingCharacters(in: .whitespacesAndNewlines), "")
        }
        var codeBody = String(afterOpen[..<closeFence.lowerBound])
        // Drop the language tag line (e.g. "python") after the opening fence.
        if let nl = codeBody.firstIndex(of: "\n") {
            let firstLine = codeBody[..<nl].trimmingCharacters(in: .whitespaces)
            if !firstLine.isEmpty && !firstLine.contains(" ") {
                codeBody = String(codeBody[codeBody.index(after: nl)...])
            }
        }
        let note = String(afterOpen[closeFence.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (codeBody.trimmingCharacters(in: .whitespacesAndNewlines), note)
    }
}
