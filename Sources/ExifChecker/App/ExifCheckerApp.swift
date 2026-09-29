import SwiftUI

/// The SwiftUI application. The full UI is assembled in `Views/`; this file
/// only configures the scene and the activation policy.
struct ExifCheckerApp: App {

    init() {
        // SPM executables are not bundled apps: without a regular activation
        // policy no window would come to the foreground (or appear at all).
        // Inside the .app bundle produced by `make bundle` this is a no-op.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("ExifChecker") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 680)
    }
}
