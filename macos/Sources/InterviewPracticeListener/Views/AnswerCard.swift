import SwiftUI

/// A titled, rounded card holding one answer section. Text is selectable and
/// copyable; long content scrolls within a bounded height so the window never
/// grows past the screen.
struct AnswerCard: View {
    let title: String
    let text: String
    var isLoading: Bool = false
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .kerning(0.5)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
                Spacer()
                if !text.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("Copy")
                }
            }

            if text.isEmpty {
                Text(isLoading ? "Generating…" : "—")
                    .font(.system(size: fontSize))
                    .foregroundColor(.secondary.opacity(0.6))
            } else {
                Text(text)
                    .font(.system(size: fontSize))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
