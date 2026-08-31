import SwiftUI
import UniformTypeIdentifiers

/// Settings panel. Exposes backend URL, model, appearance, behavior, and the
/// candidate context (role/JD/company/resume/additional). API key is optional
/// and for local testing only — the backend owns credentials.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var vm: InterviewViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                group("Backend") {
                    labeled("Backend URL") { TextField("http://localhost:8000", text: $settings.backendURL) }
                    labeled("Model") {
                        Picker("", selection: $settings.model) {
                            ForEach(AppSettings.modelOptions, id: \.self) { Text($0) }
                        }.labelsHidden()
                    }
                    labeled("API key (optional, local testing)") {
                        SecureField("Leave empty to use backend key", text: $settings.apiKey)
                    }
                    Button("Test Backend & Model") { Task { await vm.testBackend() } }
                }

                group("Behavior") {
                    Toggle("Auto-start listening on launch", isOn: $settings.autoStartListening)
                    Toggle("Auto-generate on silence", isOn: $settings.autoOnSilence)
                    labeled("Silence timeout: \(String(format: "%.1f", settings.silenceTimeout))s") {
                        Slider(value: $settings.silenceTimeout, in: 1...5, step: 0.5)
                    }
                    Toggle("Compact mode by default", isOn: $settings.compactByDefault)
                }

                group("Appearance") {
                    Toggle("Always on top", isOn: $settings.alwaysOnTop)
                    labeled("Opacity: \(Int(settings.opacity * 100))%") {
                        Slider(value: $settings.opacity, in: 0.4...1.0, step: 0.02)
                    }
                    labeled("Font size: \(Int(settings.fontSize))") {
                        Slider(value: $settings.fontSize, in: 11...20, step: 1)
                    }
                }

                group("Experimental Compatibility") {
                    Toggle("Experimental Window Sharing Exclusion",
                           isOn: $settings.experimentalSharingExclusion)
                    Text("Experimental compatibility setting. Applies an AppKit window-sharing preference (sharingType = .none). Behavior with third-party capture software (Zoom, Teams, Meet, Webex) depends on macOS and the capture application and is not guaranteed. This is not a supported privacy boundary.")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }

                group("Candidate Context") {
                    labeled("Role / Title") { TextField("Senior DevOps Engineer", text: $settings.role) }
                    labeled("Company / Industry") { TextField("Company, industry", text: $settings.companyContext) }
                    labeled("Job Description") {
                        TextEditor(text: $settings.jobDescription).frame(height: 60)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    }
                    HStack {
                        Button("Upload Resume…") { pickFile { url in Task { await vm.uploadResume(url) } } }
                        Button("Upload Context…") { pickFile { url in Task { await vm.uploadContext(url) } } }
                    }
                    labeled("Resume Text") {
                        TextEditor(text: $settings.resumeText).frame(height: 60)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    }
                    labeled("Additional Context") {
                        TextEditor(text: $settings.additionalContext).frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    }
                    Button("Analyze Resume + JD") { Task { await vm.analyzeProfile() } }
                }

                group("Speech Corrections") {
                    CorrectionsManagerView(store: vm.corrections)
                }

                group("Evaluate My Answer") {
                    EvaluateView().environmentObject(vm)
                }

                group("Session History") {
                    Text("\(vm.history.count) answer(s) this session")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Button("Export Q&A History…") { exportHistory() }
                        .disabled(vm.history.isEmpty)
                }

                group("Shortcuts") {
                    Text("⌘⇧Space  — Show/Hide").font(.system(size: 11)).foregroundColor(.secondary)
                    Text("⌘⇧L  — Start/Stop Listening").font(.system(size: 11)).foregroundColor(.secondary)
                    Text("⌘⇧C  — Compact/Expanded").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(14)
        }
    }

    private var header: some View {
        HStack {
            Text("Settings").font(.system(size: 15, weight: .semibold))
            Spacer()
            Button("Done") { isPresented = false }
        }
    }

    @ViewBuilder
    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary).kerning(0.5)
            content()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
            content()
        }
    }

    private func exportHistory() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "interview-practice-answers.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        if panel.runModal() == .OK, let url = panel.url {
            try? vm.historyMarkdown().write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func pickFile(_ completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText,
            UTType(filenameExtension: "docx") ?? .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { completion(url) }
    }
}
