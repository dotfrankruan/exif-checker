import SwiftUI

/// Temporary scaffold application.
///
/// The real entry point (GUI + `--dump` CLI mode) is implemented in a later
/// commit; this file only proves that the package layout builds.
struct ScaffoldApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ExifChecker scaffold")
                .frame(minWidth: 320, minHeight: 200)
        }
    }
}

// No `@main` attribute on purpose: this target ships a `main.swift` so the
// entry point can branch between GUI mode and CLI dump mode.
ScaffoldApp.main()
