import SwiftUI

/// Shows the live transcript and a manual question box, plus the Start/Stop
/// listening control. Mirrors the browser's "Listen or Enter Question" area.
struct TranscriptView: View {
    @EnvironmentObject var vm: InterviewViewModel
    @ObservedObject var speech: SpeechRecognizer
    @State private var questionBoxExpanded: Bool = false
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
                    let text = vm.editableQuestion.isEmpty ? speech.transcript : vm.editableQuestion
                    vm.liveTranscript = text
                    Task { await vm.detectQuestion() }
                }
                .disabled(vm.editableQuestion.isEmpty && speech.transcript.isEmpty)
                .help("Detect the latest interview question without generating an answer")

                Button("Generate") {
                    let text = vm.editableQuestion.isEmpty ? speech.transcript : vm.editableQuestion
                    Task { await vm.generateFromManualTranscript(text) }
                }
                .disabled(vm.editableQuestion.isEmpty && speech.transcript.isEmpty)
            }

            // Detected-question metadata (type · topic · difficulty). The
            // question text itself is placed into the editable box below.
            if let d = vm.detected,
               !([d.question_type, d.topic, d.difficulty].compactMap { $0 }.filter { !$0.isEmpty }).isEmpty {
                Text([d.question_type, d.topic, d.difficulty]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 10)).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

            // The detected question is placed here automatically so it can be
            // corrected, then re-run with Generate. Also used to type a
            // question manually.
            DisclosureGroup(isExpanded: $questionBoxExpanded) {
                TextEditor(text: $vm.editableQuestion)
                    .font(.system(size: fontSize - 1))
                    .frame(height: 60)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            } label: {
                Text("Type a question / transcript")
            }
            .font(.system(size: 11))
            .onChange(of: vm.editableQuestion) { newValue in
                // Auto-open the box when a detected question populates it.
                if !newValue.isEmpty { questionBoxExpanded = true }
            }
        }
    }
}
