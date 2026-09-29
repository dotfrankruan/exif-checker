import ExifCheckerCore
import Foundation

/// Command line interface, inspired by `exiftool` and `ffprobe`.
///
/// Usage:
///     ExifChecker --dump <file>
///
/// Prints all extracted metadata to stdout in an exiftool-like grouped
/// layout and exits with a status code. This mode is also handy for
/// automated testing of the extraction pipeline without a GUI.
enum CLIDumper {

    /// POSIX-style exit statuses.
    private static let exitOK: Int32 = 0
    private static let exitFailure: Int32 = 1
    private static let exitUsage: Int32 = 64 // EX_USAGE

    /// Returns `true` when the process was invoked in CLI mode.
    static func wantsCLI(_ arguments: [String]) -> Bool {
        arguments.count > 1 && (arguments[1] == "--dump" || arguments[1] == "-d")
    }

    /// Runs the dump. Returns the process exit code.
    static func run(_ arguments: [String]) async -> Int32 {
        guard wantsCLI(arguments), arguments.count > 2 else {
            fputs("usage: ExifChecker --dump <file>\n", stderr)
            return exitUsage
        }

        let path = (arguments[2] as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path).standardizedFileURL
        do {
            let document = try await MetadataLoader.load(from: url)
            print(document.plainTextReport())
            return exitOK
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            return exitFailure
        }
    }
}
