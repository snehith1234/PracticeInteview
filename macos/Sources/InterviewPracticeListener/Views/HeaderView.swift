import SwiftUI

/// Compact header: status dot + label on the left; window controls on the right.
struct HeaderView: View {
    @EnvironmentObject var vm: InterviewViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 10) {
            statusDot
            Text(vm.listeningState.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Button(action: { Task { await vm.captureScreenshot() } }) {
                if vm.isCapturing {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else {
                    Image(systemName: "camera")
                }
            }
            .disabled(vm.isCapturing)
            .help("Capture full screen + extract text")

            Button(action: { vm.isCompact.toggle() }) {
                Image(systemName: vm.isCompact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
            }
            .help(vm.isCompact ? "Expand" : "Compact")

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape")
            }
            .help("Settings")

            Button(action: { NSApp.keyWindow?.orderOut(nil) }) {
                Image(systemName: "minus.circle")
            }
            .help("Hide (⌘⇧Space to show)")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
    }

    private var dotColor: Color {
        switch vm.listeningState {
        case .listening: return .green
        case .processing: return .orange
        case .paused, .idle: return .gray
        case .backendOffline, .micPermissionRequired, .speechPermissionRequired, .error:
            return .red
        }
    }
}
