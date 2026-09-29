import AppKit

/// Application delegate for lifecycle behavior SwiftUI does not cover.
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Called when the user clicks the Dock icon or re-launches the app
    /// (e.g. double-clicks it in Finder) while it is already running.
    ///
    /// Without this, re-opening an app whose window was closed appears to
    /// "do nothing" — the process is alive but no window is visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowController.reopen()
        }
        return true
    }
}

/// Recreates the main window on demand.
///
/// The SwiftUI `openWindow` environment action is captured by the content
/// view and stored here, so the app delegate can reopen the window even
/// after it was closed (at which point no view is alive to observe
/// notifications).
@MainActor
enum MainWindowController {
    /// Scene id of the single main window.
    static let windowID = "main"

    /// Captured `openWindow(id:)` action from the SwiftUI environment.
    static var openWindowAction: (() -> Void)?

    static func reopen() {
        if let action = openWindowAction {
            action()
        } else {
            // Fallback: bring any existing window back to front.
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }
}
