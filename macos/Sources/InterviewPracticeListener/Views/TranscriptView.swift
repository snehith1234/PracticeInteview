import SwiftUI

/// Shows the live transcript and a manual question box, plus the Start/Stop
/// listening control. Mirrors the browser's "Listen or Enter Question" area.
struct TranscriptView: View {
    @EnvironmentObject var vm: InterviewViewModel
    @ObservedObject var speech: SpeechRecognizer
    @State private var manualText: String = ""
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: { Task { await vm.toggleListening() } }) {
                    Label(speech.isListening ? "Stop & Generate" : "Start Listening",
                          systemImage: speech.isListening ? "stop.circle.fill" : "mic.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(speech.isListening ? .red : .accentColor)

                Button("Detect") {
                    let text = manualText.isEmpty ? speech.transcript : manualText
                    vm.liveTranscript = text
                    Task { await vm.detectQuestion() }
                }
                .disabled(manualText.isEmpty && speech.transcript.isEmpty)
                .help("Detect the latest interview question without generating an answer")

                Button("Generate") {
                    let text = manualText.isEmpty ? speech.transcript : manualText
                    Task { await vm.generateFromManualTranscript(text) }
                }
                .disabled(manualText.isEmpty && speech.transcript.isEmpty)
            }

            if let d = vm.detected, let q = d.clean_question, !q.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(q).font(.system(size: fontSize - 1, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text([d.question_type, d.topic, d.difficulty]
                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.12)))
            }

            let live = speech.partial.isEmpty ? speech.transcript : (speech.transcript + " " + speech.partial)
            if !live.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(live)
                    .font(.system(size: fontSize - 1))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            }

            DisclosureGroup("Or type a question / transcript") {
                TextEditor(text: $manualText)
                    .font(.system(size: fontSize - 1))
                    .frame(height: 60)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            }
            .font(.system(size: 11))
        }
    }
}
