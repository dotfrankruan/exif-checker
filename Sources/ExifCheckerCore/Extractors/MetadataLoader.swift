import Foundation
import UniformTypeIdentifiers

/// Top level dispatcher that routes a file to the right extractor chain.
///
/// Strategy:
///   1. Always extract file system information (like exiftool's `[System]`).
///   2. Images (per UTI) go to ImageIO; audiovisual content goes to
///      AVFoundation.
///   3. Unknown types try ImageIO first, then AVFoundation — this catches
///      mis-extensioned files gracefully.
///   4. If nothing can parse the file, the document still contains the file
///      system group plus an explanatory note.
public enum MetadataLoader {

    /// Loads and extracts all metadata for the file at `url`.
    /// - Throws: ``ExtractionError/unreadableFile(_:)`` when the file is missing.
    public static func load(from url: URL) async throws -> MetadataDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.unreadableFile(url.path)
        }

        let fileSize = FileMetadataExtractor.fileSize(of: url)
        let contentType = FileMetadataExtractor.contentType(of: url)

        var groups: [MetadataGroup] = [FileMetadataExtractor.extract(from: url)]
        var kind: MediaKind = .other
        var handled = false

        let conformsToImage = contentType?.conforms(to: .image) ?? false
        let conformsToAV = contentType?.conforms(to: .audiovisualContent) ?? false

        // Images (and unknown formats) try ImageIO first.
        if conformsToImage || !conformsToAV {
            if ImageMetadataExtractor.canHandle(url: url) {
                let imageGroups = ImageMetadataExtractor.extract(from: url)
                if !imageGroups.isEmpty {
                    groups.append(contentsOf: imageGroups)
                    kind = .image
                    handled = true
                }
            }
        }

        // Everything else (or fallback) tries AVFoundation.
        if !handled {
            let avGroups = await AVMetadataExtractor.extract(from: url, fileSize: fileSize)
            if !avGroups.isEmpty {
                groups.append(contentsOf: avGroups)
                if contentType?.conforms(to: .audio) ?? false {
                    kind = .audio
                } else {
                    kind = .video
                }
                handled = true
            }
        }

        if !handled {
            var noteBuilder = GroupBuilder(name: "Note")
            noteBuilder.addFormatted(
                "Note",
                "Format is not natively readable by ImageIO or AVFoundation; showing file system information only."
            )
            groups.append(noteBuilder.group)
        }

        return MetadataDocument(
            fileURL: url,
            fileSize: fileSize,
            contentType: contentType,
            kind: kind,
            groups: groups
        )
    }
}
