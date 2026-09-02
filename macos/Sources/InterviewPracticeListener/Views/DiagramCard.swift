import SwiftUI

/// Renders the "# Diagram" section for design/architecture/workflow questions:
/// an ASCII flow/box diagram in a monospaced, scrollable view with a copy
/// button. Uses the same fence-stripping as CodeCard so ```text blocks render
/// cleanly.
struct DiagramCard: View {
    let raw: String
    let fontSize: Double

    var body: some View {
        let (diagram, _) = CodeCard.splitCodeAndNote(raw)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DIAGRAM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                    .kerning(0.5)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(diagram, forType: .string)
                } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)) }
                .buttonStyle(.borderless)
                .help("Copy diagram")
            }

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(diagram)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(10)
            }
            .frame(maxHeight: 260)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.purple.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.25), lineWidth: 1))
        )
    }
}
