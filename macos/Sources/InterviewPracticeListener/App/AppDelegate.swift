import AppKit
import SwiftUI

/// Bootstraps the floating panel, global hotkeys, and shared state. Runs as an
/// accessory app (no Dock icon / menu bar clutter) so it feels like a utility.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = AppSettings()
    lazy var viewModel = InterviewViewModel(settings: settings)
    private var overlay: OverlayController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory: floating utility, not a normal windowed app.
        NSApp.setActivationPolicy(.accessory)

        overlay = OverlayController(settings: settings, viewModel: viewModel)
        // Briefly activate so the borderless accessory panel is guaranteed to
        // appear frontmost on first launch.
        NSApp.activate(ignoringOtherApps: true)
        overlay.show()

        // Global shortcuts (fire even when another app is focused).
        let hk = HotkeyManager.shared
        hk.onToggleVisibility = { [weak self] in self?.overlay.toggleVisibility() }
        hk.onToggleListening = { [weak self] in
            guard let self else { return }
            Task { await self.viewModel.toggleListening() }
        }
        hk.onToggleCompact = { [weak self] in
            self?.viewModel.isCompact.toggle()
        }
        hk.register()

        // Optional auto-start listening.
        if settings.autoStartListening {
            Task { await viewModel.startListening() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
