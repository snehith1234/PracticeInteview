import AppKit

/// Borderless, floating NSPanel used as the assistant window.
///
/// Uses only standard, documented AppKit APIs for normal desktop behavior:
///   - floating window level (stays above normal windows when always-on-top)
///   - appears across Spaces and alongside fullscreen apps where the OS allows
///   - movable by dragging the background
///
/// It intentionally does NOT attempt any screen-capture exclusion / stealth.
final class OverlayPanel: NSPanel {

    init(contentRect: NSRect) {
        // `.fullSizeContentView` requires a titled window; combining it with
        // `.borderless` raises an NSInternalInconsistencyException. Use a
        // titled+resizable panel and hide the titlebar chrome instead.
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable,
                        .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        // NOTE: .canJoinAllSpaces and .moveToActiveSpace are mutually
        // exclusive — using both raises NSInternalInconsistencyException.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        title = "Interview Practice Listener"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true

        // Hide the traffic-light buttons for a clean floating look. The window
        // stays movable (drag background) and resizable (drag edges/corners)
        // via the style mask; hide/minimize is offered in the SwiftUI header.
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // A titled panel with a transparent titlebar keeps the rounded floating
        // look while giving real, draggable window chrome.
        isOpaque = false
        hasShadow = true

        // Force dark appearance so SwiftUI's semantic text colors (.primary /
        // .secondary) render light on the dark panel background.
        appearance = NSAppearance(named: .darkAqua)

        // Allow interaction without stealing focus from the foreground app.
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true

        minSize = NSSize(width: 320, height: 220)
    }

    // Panels must opt in to becoming key/main so text fields and window
    // controls (traffic lights) work normally.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Accessory apps have no Dock icon, so a normal miniaturize would send the
    /// window nowhere. Instead, hide it — ⌘⇧Space brings it back.
    override func miniaturize(_ sender: Any?) {
        orderOut(nil)
    }

    /// Close should also just hide (so the app keeps running and can be
    /// re-summoned with the global shortcut) rather than destroying the window.
    override func close() {
        orderOut(nil)
    }

    func setAlwaysOnTop(_ on: Bool) {
        level = on ? .floating : .normal
    }
}
