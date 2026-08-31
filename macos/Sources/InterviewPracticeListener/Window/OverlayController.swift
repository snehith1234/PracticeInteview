import AppKit
import SwiftUI
import Combine

/// Owns the OverlayPanel, hosts the SwiftUI content, and wires window
/// persistence (position/size), opacity, always-on-top, and show/hide.
@MainActor
final class OverlayController: NSObject, NSWindowDelegate {

    private let panel: OverlayPanel
    private let settings: AppSettings
    private let viewModel: InterviewViewModel
    private let privacyConfigurator = WindowPrivacyConfigurator()
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings, viewModel: InterviewViewModel) {
        self.settings = settings
        self.viewModel = viewModel

        let defaultRect = NSRect(x: 0, y: 0, width: 420, height: 620)
        // Use the saved frame only if it is still on a visible screen; otherwise
        // center it (guards against off-screen frames from a disconnected display).
        let saved = WindowFrameStore.load()
        let onScreen = saved.map { rect in
            NSScreen.screens.contains { $0.visibleFrame.intersects(rect) }
        } ?? false
        let frame = (saved != nil && onScreen) ? saved! : OverlayController.centeredRect(defaultRect)
        self.panel = OverlayPanel(contentRect: frame)

        super.init()

        let root = OverlayView()
            .environmentObject(settings)
            .environmentObject(viewModel)
            .preferredColorScheme(.dark)

        let hosting = NSHostingView(rootView: root)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 16
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        panel.delegate = self

        applyOpacity(settings.opacity)
        panel.setAlwaysOnTop(settings.alwaysOnTop)

        // Let the view model hide/show this panel during screen capture so the
        // assistant window isn't included in the screenshot.
        viewModel.hidePanelForCapture = { [weak self] in self?.panel.orderOut(nil) }
        viewModel.showPanelAfterCapture = { [weak self] in self?.show() }
        applyExperimentalSharing()

        // React to settings changes.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                self.applyOpacity(self.settings.opacity)
                self.panel.setAlwaysOnTop(self.settings.alwaysOnTop)
                self.applyExperimentalSharing()
            }
            .store(in: &cancellables)
    }

    /// Feature B — apply the experimental sharing setting through the ONE
    /// centralized configurator. Never scattered elsewhere.
    private func applyExperimentalSharing() {
        let mode = privacyConfigurator.mode(experimentalEnabled: settings.experimentalSharingExclusion)
        privacyConfigurator.configure(window: panel, mode: mode)
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func toggleVisibility() {
        if panel.isVisible { panel.orderOut(nil) }
        else { show() }
    }

    private func applyOpacity(_ value: Double) {
        panel.alphaValue = CGFloat(max(0.4, min(1.0, value)))
    }

    private static func centeredRect(_ rect: NSRect) -> NSRect {
        guard let screen = NSScreen.main else { return rect }
        let vf = screen.visibleFrame
        return NSRect(
            x: vf.midX - rect.width / 2,
            y: vf.midY - rect.height / 2,
            width: rect.width, height: rect.height
        )
    }

    // MARK: - NSWindowDelegate (persist frame)

    func windowDidMove(_ notification: Notification) { WindowFrameStore.save(panel.frame) }
    func windowDidResize(_ notification: Notification) { WindowFrameStore.save(panel.frame) }
}
