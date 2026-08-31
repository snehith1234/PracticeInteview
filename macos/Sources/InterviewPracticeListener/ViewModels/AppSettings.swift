import Foundation
import SwiftUI

/// User-configurable settings, persisted via UserDefaults (@AppStorage).
///
/// API/model credentials stay in the BACKEND (.env). The optional `apiKey`
/// field here mirrors the browser app's optional key field for local testing
/// only and is sent via the `x-openai-api-key` header exactly as the browser
/// does — it is not required.
@MainActor
final class AppSettings: ObservableObject {

    // Backend
    @AppStorage("backendURL") var backendURL: String = "http://localhost:8000"
    @AppStorage("model") var model: String = "gpt-4o-mini"
    @AppStorage("apiKey") var apiKey: String = "" // local testing only

    // Behavior
    @AppStorage("autoStartListening") var autoStartListening: Bool = false
    @AppStorage("autoOnSilence") var autoOnSilence: Bool = true
    @AppStorage("silenceTimeout") var silenceTimeout: Double = 2.0 // matches SILENCE_TIMEOUT_MS

    // Appearance
    @AppStorage("opacity") var opacity: Double = 0.96
    @AppStorage("fontSize") var fontSize: Double = 13
    @AppStorage("compactByDefault") var compactByDefault: Bool = false
    @AppStorage("alwaysOnTop") var alwaysOnTop: Bool = true

    // Experimental Window Sharing Exclusion (Feature B).
    // When ON, applies AppKit's `NSWindow.sharingType = .none` via the
    // centralized WindowPrivacyConfigurator. EXPERIMENTAL: behavior with
    // third-party capture software varies by macOS/app and is NOT guaranteed.
    @AppStorage("experimentalSharingExclusion") var experimentalSharingExclusion: Bool = false

    // Candidate context (persisted so it survives restarts, like the browser
    // app keeps it in component state during a session)
    @AppStorage("role") var role: String = ""
    @AppStorage("jobDescription") var jobDescription: String = ""
    @AppStorage("companyContext") var companyContext: String = ""
    @AppStorage("resumeText") var resumeText: String = ""
    @AppStorage("additionalContext") var additionalContext: String = ""

    static let modelOptions = [
        "gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "gpt-4.1",
        "gpt-5.4-mini", "gpt-5.4", "gpt-5.5"
    ]
}

/// Window frame persistence lives outside @AppStorage because it is set from
/// AppKit (NSPanel) callbacks.
enum WindowFrameStore {
    private static let key = "overlayWindowFrame"

    static func save(_ frame: NSRect) {
        let dict = ["x": frame.origin.x, "y": frame.origin.y,
                    "w": frame.size.width, "h": frame.size.height]
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func load() -> NSRect? {
        guard let d = UserDefaults.standard.dictionary(forKey: key) as? [String: Double],
              let x = d["x"], let y = d["y"], let w = d["w"], let h = d["h"], w > 0, h > 0
        else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }
}
