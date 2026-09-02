import AppKit
import SwiftUI

/// Bootstraps the floating panel, global hotkeys, and shared state. Runs as an
/// accessory app (no Dock icon / menu bar clutter) so it feels like a utility.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = AppSettings()
    lazy var viewModel = InterviewViewModel(settings: settings)
    private var overlay: OverlayController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular app so there is a Dock icon — this guarantees the window can
        // ALWAYS be recovered (click the Dock icon) even if the menu bar item
        // and global hotkey both fail. Also enables reopen-on-Dock-click below.
        NSApp.setActivationPolicy(.regular)

        overlay = OverlayController(settings: settings, viewModel: viewModel)
        // Briefly activate so the borderless accessory panel is guaranteed to
        // appear frontmost on first launch.
        NSApp.activate(ignoringOtherApps: true)
        overlay.show()

        // Persistent menu bar icon — always available to show/hide the window,
        // so a hidden window can ALWAYS be recovered even if the global hotkey
        // fails to register.
        setupStatusItem()

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

    /// Clicking the Dock icon (when no windows are visible) re-shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        overlay?.show()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    // MARK: - Menu bar status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "questionmark.bubble",
                                 accessibilityDescription: "Interview Practice Listener") {
                img.isTemplate = true
                button.image = img
            } else {
                // Fallback so the item is ALWAYS visible even if the symbol
                // can't load on this macOS version.
                button.title = "IPL"
            }
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide  (⌘⇧Space)",
                     action: #selector(toggleWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Start / Stop Listening  (⌘⇧L)",
                     action: #selector(toggleListening), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Interview Practice Listener",
                     action: #selector(quitApp), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func toggleWindow() { overlay.toggleVisibility() }
    @objc private func toggleListening() { Task { await viewModel.toggleListening() } }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
