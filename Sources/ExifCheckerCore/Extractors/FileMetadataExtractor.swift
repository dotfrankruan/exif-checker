import Foundation
import UniformTypeIdentifiers

/// Extracts file system level metadata (name, size, dates, UTI, MIME type).
///
/// This group is always present, even for formats no media framework can
/// parse — mirroring exiftool's `[System]` / `[File]` groups.
public enum FileMetadataExtractor {

    /// Builds the "File System" group for the given URL.
    public static func extract(from url: URL) -> MetadataGroup {
        var builder = GroupBuilder(name: "File System")
        builder.addFormatted("FileName", url.lastPathComponent)
        builder.addFormatted("FilePath", url.path)

        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            if let size = attributes[.size] as? NSNumber {
                builder.addFormatted("FileSize", ValueFormatter.byteCountString(size.int64Value))
            }
            // Both dates go through the shared date formatter via GroupBuilder.
            builder.add("FileCreationDate", attributes[.creationDate] as? Date)
            builder.add("FileModificationDate", attributes[.modificationDate] as? Date)
        }

        let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
        if let contentType {
            let description = contentType.localizedDescription ?? contentType.identifier
            builder.addFormatted("ContentType", "\(description) (\(contentType.identifier))")
            if let mime = contentType.preferredMIMEType {
                builder.addFormatted("MIMEType", mime)
            }
        }
        return builder.group
    }

    /// Returns the file size in bytes, or 0 when it cannot be determined.
    public static func fileSize(of url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Resolves the content type of the file from the file system,
    /// falling back to the path extension.
    public static func contentType(of url: URL) -> UTType? {
        (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
            ?? UTType(filenameExtension: url.pathExtension)
    }
}
