import SwiftUI

/// Entry point. The real window is a floating NSPanel created by AppDelegate,
/// so the SwiftUI `Settings` scene is used only to satisfy the App protocol
/// without creating an extra normal window.
@main
struct InterviewPracticeListenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
