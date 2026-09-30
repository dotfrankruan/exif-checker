import SwiftUI

/// Entry point with two modes, mirroring the dual nature of `exiftool` /
/// `ffprobe` (CLI) and a friendly desktop app (GUI):
///
///     ExifChecker                           -> launches the SwiftUI application
///     ExifChecker --dump <file> [<file> …]  -> prints metadata exiftool-style, exits
///     ExifChecker --help                    -> prints CLI usage, exits
///
/// Note: there is intentionally no `@main` attribute anywhere in this
/// target — `main.swift` takes precedence so we can branch first.
if CLIDumper.wantsCLI(CommandLine.arguments) {
    let exitCode = await CLIDumper.run(CommandLine.arguments)
    Foundation.exit(exitCode)
}

// GUI mode: hand over to the SwiftUI app lifecycle.
ExifCheckerApp.main()
