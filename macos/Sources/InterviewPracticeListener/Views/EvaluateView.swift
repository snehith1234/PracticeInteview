import SwiftUI

/// "Evaluate My Own Answer" tool (POST /coach/evaluate). Lives in Settings.
/// Prefills the question from the current detected/answered question.
struct EvaluateView: View {
    @EnvironmentObject var vm: InterviewViewModel
    @State private var question = ""
    @State private var userAnswer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Question", text: $question).textFieldStyle(.roundedBorder)
            TextEditor(text: $userAnswer)
                .frame(height: 60)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                .overlay(alignment: .topLeading) {
                    if userAnswer.isEmpty {
                        Text("Type your answer…").foregroundColor(.secondary.opacity(0.5))
                            .padding(6).allowsHitTesting(false).font(.system(size: 11))
                    }
                }
            HStack {
                Button("Evaluate My Answer") {
                    Task { await vm.evaluate(question: question, userAnswer: userAnswer) }
                }
                .disabled(question.isEmpty || userAnswer.isEmpty || vm.isEvaluating)
                if vm.isEvaluating { ProgressView().controlSize(.small) }
                Button("Use current question") {
                    question = vm.answer.question
                }
                .disabled(vm.answer.question.isEmpty)
                .font(.system(size: 10))
            }

            if !vm.evaluationFeedback.isEmpty {
                ScrollView {
                    Text(vm.evaluationFeedback)
                        .font(.system(size: 11)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
            }
        }
        .font(.system(size: 11))
    }
}
