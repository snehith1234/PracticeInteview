import SwiftUI

/// Shows the result of a full-screen capture: the saved image path and the
/// OCR-extracted text, with actions to copy the text, reveal the saved image
/// in Finder, generate an answer from the text, or clear it.
struct ScreenshotView: View {
    @EnvironmentObject var vm: InterviewViewModel
    let fontSize: Double

    var body: some View {
        if !vm.screenshotText.isEmpty || !vm.screenshotPath.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SCREENSHOT TEXT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .kerning(0.5)
                    Spacer()
                    if !vm.screenshotText.isEmpty {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(vm.screenshotText, forType: .string)
                        } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)) }
                        .buttonStyle(.borderless).help("Copy text")
                    }
                    if !vm.screenshotPath.isEmpty {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: vm.screenshotPath)
                            ])
                        } label: { Image(systemName: "photo").font(.system(size: 10)) }
                        .buttonStyle(.borderless).help("Reveal image in Finder")
                    }
                    Button {
                        vm.screenshotText = ""
                        vm.screenshotPath = ""
                    } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.borderless).help("Clear")
                }

                if !vm.screenshotText.isEmpty {
                    ScrollView {
                        Text(vm.screenshotText)
                            .font(.system(size: fontSize - 1))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.25)))

                    Button("Use as question → Generate") {
                        Task { await vm.generateFromScreenshotText() }
                    }
                    .font(.system(size: 11))
                } else {
                    Text("Saved: \(URL(fileURLWithPath: vm.screenshotPath).lastPathComponent)")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25), lineWidth: 1))
            )
        }
    }
}
