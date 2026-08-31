import SwiftUI
import UniformTypeIdentifiers

/// Full speech-corrections manager (add / edit / delete / import / export),
/// mirroring the browser's corrections panel. Lives in Settings.
struct CorrectionsManagerView: View {
    @ObservedObject var store: CorrectionStore

    @State private var wrong = ""
    @State private var correct = ""
    @State private var domain = ""
    @State private var editingID: UUID?
    @State private var editBuffer = SpeechCorrection(wrong: "", correct: "", domain: "")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.items) { item in
                if editingID == item.id {
                    HStack(spacing: 4) {
                        TextField("wrong", text: $editBuffer.wrong).textFieldStyle(.roundedBorder)
                        TextField("correct", text: $editBuffer.correct).textFieldStyle(.roundedBorder)
                        TextField("domain", text: $editBuffer.domain).textFieldStyle(.roundedBorder).frame(width: 80)
                        Button("✓") { store.update(editBuffer); editingID = nil }
                        Button("✕") { editingID = nil }
                    }
                    .font(.system(size: 11))
                } else {
                    HStack(spacing: 6) {
                        Text(item.wrong).foregroundColor(.red)
                        Text("→").foregroundColor(.secondary)
                        Text(item.correct).foregroundColor(.green)
                        Text(item.domain).font(.system(size: 9))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1)))
                        Spacer()
                        Button { editingID = item.id; editBuffer = item } label: { Image(systemName: "pencil") }
                            .buttonStyle(.borderless)
                        Button { store.delete(item) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).foregroundColor(.red)
                    }
                    .font(.system(size: 11))
                }
            }

            HStack(spacing: 4) {
                TextField("Heard wrong", text: $wrong).textFieldStyle(.roundedBorder)
                TextField("Should be", text: $correct).textFieldStyle(.roundedBorder)
                TextField("Domain", text: $domain).textFieldStyle(.roundedBorder).frame(width: 80)
                Button("+ Add") {
                    store.add(wrong: wrong, correct: correct, domain: domain)
                    wrong = ""; correct = ""; domain = ""
                }
                .disabled(wrong.isEmpty || correct.isEmpty)
            }
            .font(.system(size: 11))

            HStack {
                Button("Export…") { exportCorrections() }
                Button("Import…") { importCorrections() }
            }
            .font(.system(size: 11))
        }
    }

    private func exportCorrections() {
        guard let data = store.exportJSON() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "speech-corrections.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func importCorrections() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            _ = store.importJSON(data)
        }
    }
}
