import SwiftUI

/// Collapsible session history of previous Q&As (mirrors the browser's
/// "Previous Questions" list). Shows all but the most recent (which is already
/// displayed live above).
struct HistoryView: View {
    let history: [InterviewAnswer]
    let fontSize: Double

    var body: some View {
        let previous = Array(history.dropFirst())
        if !previous.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("PREVIOUS QUESTIONS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary).kerning(0.5)
                ForEach(previous) { item in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 6) {
                            section("Say This Now", item.quickAnswer)
                            section("30-Second Version", item.thirtySecond)
                            section("Real-Time Example", item.realTimeExample)
                            section("Strong Answer", item.strongAnswer)
                        }
                        .padding(.top, 4)
                    } label: {
                        Text(item.question.isEmpty ? "Question" : item.question)
                            .font(.system(size: fontSize - 1, weight: .medium))
                            .lineLimit(1)
                    }
                    .font(.system(size: fontSize - 1))
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                Text(text).font(.system(size: fontSize - 1)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
