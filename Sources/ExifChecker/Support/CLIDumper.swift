import ExifCheckerCore
import Foundation

/// Command line interface, inspired by `exiftool` and `ffprobe`.
///
/// Usage:
///     ExifChecker --dump <file> [<file> ...]
///     ExifChecker --help
///
/// Prints all extracted metadata to stdout in an exiftool-like grouped
/// layout and exits with a status code. This mode is also handy for
/// automated testing of the extraction pipeline without a GUI.
enum CLIDumper {

    /// POSIX-style exit statuses.
    private static let exitOK: Int32 = 0
    private static let exitFailure: Int32 = 1
    private static let exitUsage: Int32 = 64 // EX_USAGE

    private static let usage = """
        usage: ExifChecker --dump <file> [<file> ...]
               ExifChecker -d <file>          (same as --dump)
               ExifChecker --help             show this text
        """

    /// Returns `true` when the process was invoked in CLI mode.
    static func wantsCLI(_ arguments: [String]) -> Bool {
        guard arguments.count > 1 else { return false }
        // Any option belongs to the CLI. Unknown options should report
        // usage instead of unexpectedly launching the graphical app.
        return arguments[1].hasPrefix("-")
    }

    /// Runs the CLI command. Returns the process exit code.
    static func run(_ arguments: [String]) async -> Int32 {
        guard wantsCLI(arguments) else {
            fputs(usage + "\n", stderr)
            return exitUsage
        }

        if arguments[1] == "--help" || arguments[1] == "-h" {
            print(usage)
            return exitOK
        }
        guard arguments[1] == "--dump" || arguments[1] == "-d" else {
            fputs(usage + "\n", stderr)
            return exitUsage
        }

        let paths = Array(arguments.dropFirst(2))
        guard !paths.isEmpty else {
            fputs(usage + "\n", stderr)
            return exitUsage
        }

        // Dump every given file (exiftool accepts multiple files too).
        // Reports are separated by a blank line; each report itself starts
        // with a "File: <path>" header, so the output stays unambiguous.
        var exitCode = exitOK
        for (index, path) in paths.enumerated() {
            let expanded = (path as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded).standardizedFileURL
            do {
                let document = try await MetadataLoader.load(from: url)
                if index > 0 { print() }
                print(document.plainTextReport())
            } catch {
                fputs("error: \(path): \(error.localizedDescription)\n", stderr)
                exitCode = exitFailure
            }
        }
        return exitCode
    }
}
