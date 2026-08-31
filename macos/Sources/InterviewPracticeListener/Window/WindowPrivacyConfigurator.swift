import AppKit

/// Centralized configuration of AppKit window-level privacy-related properties.
///
/// This is the ONLY place in the codebase that sets `NSWindow.sharingType`.
/// Do not scatter `sharingType = .none` elsewhere.
///
/// ─────────────────────────────────────────────────────────────────────────
/// This is an experimental AppKit compatibility setting.
/// It must not be treated as a security boundary or guaranteed screen-capture
/// exclusion mechanism. Behavior with third-party capture software (Zoom,
/// Teams, Meet, Webex, screen recorders) varies by macOS version and by the
/// capturing application, and is NOT guaranteed.
/// ─────────────────────────────────────────────────────────────────────────
enum WindowPrivacyMode {
    /// Standard sharing — window participates in capture normally.
    case normal
    /// Experimental: set `sharingType = .none`. Compatibility testing only.
    case experimentalSharingExclusion
}

final class WindowPrivacyConfigurator {

    /// Applies the given mode to a window using only documented AppKit APIs.
    /// Returns whether the experimental sharing property was actually applied.
    @discardableResult
    func configure(window: NSWindow, mode: WindowPrivacyMode) -> Bool {
        switch mode {
        case .normal:
            window.sharingType = .readOnly
            return false
        case .experimentalSharingExclusion:
            // EXPERIMENTAL — not a guarantee against third-party capture.
            window.sharingType = .none
            return true
        }
    }

    func mode(experimentalEnabled: Bool) -> WindowPrivacyMode {
        experimentalEnabled ? .experimentalSharingExclusion : .normal
    }
}
