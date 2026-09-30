import SwiftUI

/// The SwiftUI application. All views live in `Views/`; this file configures
/// the scene, the activation policy, and the menu bar commands.
struct ExifCheckerApp: App {

    /// Bridges app-delegate events (Dock-icon reopen) into the SwiftUI app.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Shared view model so menu commands and views act on the same state.
    @StateObject private var model = AppViewModel()

    init() {
        // SPM executables are not bundled apps: without a regular activation
        // policy the window would not come to the foreground (or appear at
        // all). Inside the .app bundle produced by `make bundle` this is
        // effectively a no-op.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        // A single `Window` (not a `WindowGroup`): a metadata inspector only
        // ever needs one window, and this prevents duplicate windows when a
        // file is opened from Finder while the app is already running.
        Window("ExifChecker", id: MainWindowController.windowID) {
            ContentView(model: model)
        }
        .defaultSize(width: 980, height: 680)
        .windowResizability(.contentMinSize)
        .commands {
            // File menu additions.
            CommandGroup(after: .newItem) {
                Button("Open…") { model.openPanel() }
                    .keyboardShortcut("o")
                Divider()
                Button("Export JSON…") { model.exportJSON() }
                    .keyboardShortcut("e")
                    .disabled(model.document == nil)
                Button("Copy All Fields") { model.copyAll() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(model.document == nil)
                Button("Close File") { model.closeDocument() }
                    .keyboardShortcut("w")
                    .disabled(model.document == nil)
            }
        }
    }
}
