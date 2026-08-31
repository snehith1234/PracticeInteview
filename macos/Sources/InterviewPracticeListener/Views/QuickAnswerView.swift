import SwiftUI

/// "Say This Now" — the quick answer that arrives first, highlighted. Includes
/// the 👍/👎 vote row that opens an inline "teach a correction" form (mirrors
/// the browser's correction-teaching UX on the quick answer).
struct QuickAnswerView: View {
    let text: String
    var isLoading: Bool
    let fontSize: Double
    /// Called when the user teaches a correction: (wrong, correct, domain).
    var onTeach: (String, String, String) -> Void

    @State private var showCorrection = false
    @State private var wrong = ""
    @State private var correct = ""
    @State private var domain = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SAY THIS NOW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .kerning(0.5)
                if isLoading {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                }
                Spacer()
                if !text.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)) }
                    .buttonStyle(.borderless)
                    .help("Copy")
                }
            }

            Text(text.isEmpty ? (isLoading ? "Generating…" : "—") : text)
                .font(.system(size: fontSize + 1, weight: .medium))
                .foregroundColor(text.isEmpty ? .secondary.opacity(0.6) : .primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !text.isEmpty {
                HStack(spacing: 8) {
                    Text("Heard correctly?")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                    Button { showCorrection = false } label: { Text("👍") }
                        .buttonStyle(.borderless)
                    Button { showCorrection = true } label: { Text("👎") }
                        .buttonStyle(.borderless)
                }
                if showCorrection {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            TextField("Heard wrong", text: $wrong).textFieldStyle(.roundedBorder)
                            TextField("Should be", text: $correct).textFieldStyle(.roundedBorder)
                        }
                        HStack(spacing: 4) {
                            TextField("Domain (optional)", text: $domain).textFieldStyle(.roundedBorder)
                            Button("Save") {
                                onTeach(wrong, correct, domain)
                                wrong = ""; correct = ""; domain = ""
                                showCorrection = false
                            }
                            .disabled(wrong.isEmpty || correct.isEmpty)
                        }
                    }
                    .font(.system(size: 11))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.35), lineWidth: 1))
        )
    }
}
