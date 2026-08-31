import SwiftUI

/// Root content of the floating panel. Switches between compact (Quick Answer
/// only) and expanded (all sections) presentation. Both use the SAME generated
/// answer — compact is purely a display mode and triggers no new request.
struct OverlayView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var vm: InterviewViewModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Translucent frosted background with a subtle dark tint for
            // readability, plus a hairline border and rounded corners.
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                HeaderView(showSettings: $showSettings)
                Divider().opacity(0.4)

                if showSettings {
                    SettingsView(isPresented: $showSettings)
                        .environmentObject(settings)
                        .environmentObject(vm)
                } else {
                    content
                }
            }
        }
        .frame(minWidth: 320, minHeight: 220)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TranscriptView(speech: vm.speech, fontSize: settings.fontSize)

                if !vm.statusMessage.isEmpty {
                    Text(vm.statusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ScreenshotView(fontSize: settings.fontSize)

                if !vm.answer.question.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("QUESTION").font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary).kerning(0.5)
                        Text(vm.answer.question)
                            .font(.system(size: settings.fontSize, weight: .semibold))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                QuickAnswerView(
                    text: vm.answer.quickAnswer,
                    isLoading: vm.loadingState.quickAnswerLoading,
                    fontSize: settings.fontSize,
                    onTeach: { wrong, correct, domain in
                        vm.teachCorrection(wrong: wrong, correct: correct, domain: domain)
                    }
                )

                // Code appears in BOTH compact and expanded modes, because for
                // a coding question the code is the primary answer.
                if !vm.answer.code.isEmpty {
                    CodeCard(raw: vm.answer.code, fontSize: settings.fontSize)
                }

                if !vm.isCompact {
                    AnswerCard(title: "30-Second Version", text: vm.answer.thirtySecond,
                               isLoading: vm.loadingState.fullAnswerLoading && vm.answer.thirtySecond.isEmpty,
                               fontSize: settings.fontSize)
                    AnswerCard(title: "Real-Time Example", text: vm.answer.realTimeExample,
                               isLoading: vm.loadingState.fullAnswerLoading && vm.answer.realTimeExample.isEmpty,
                               fontSize: settings.fontSize)
                    AnswerCard(title: "Strong Answer", text: vm.answer.strongAnswer,
                               isLoading: vm.loadingState.fullAnswerLoading && vm.answer.strongAnswer.isEmpty,
                               fontSize: settings.fontSize)

                    if !vm.answer.keyPoints.isEmpty {
                        AnswerCard(title: "Key Points to Mention", text: vm.answer.keyPoints,
                                   fontSize: settings.fontSize)
                    }
                    if !vm.answer.followUpQuestions.isEmpty {
                        AnswerCard(title: "Possible Follow-Up Questions", text: vm.answer.followUpQuestions,
                                   fontSize: settings.fontSize)
                    }
                    if !vm.answer.followUpHints.isEmpty {
                        AnswerCard(title: "Follow-Up Answer Hints", text: vm.answer.followUpHints,
                                   fontSize: settings.fontSize)
                    }

                    HStack {
                        Button("Clear") { vm.clearAnswer() }
                        Spacer()
                    }
                    .font(.system(size: 11))
                    .padding(.top, 2)

                    HistoryView(history: vm.history, fontSize: settings.fontSize)
                }
            }
            .padding(12)
        }
    }
}
