import Foundation
import UniformTypeIdentifiers

/// The language used for field annotations in the UI.
public enum NoteLanguage: String, Sendable, CaseIterable {
    case english
    case chinese
}

/// A bilingual explanation of a well-known metadata field.
///
/// Annotations ship in English and Chinese; the UI picks one at display
/// time, so the language can be switched instantly without re-reading the
/// file.
public struct FieldNote: Hashable, Sendable {
    /// English explanation.
    public let en: String
    /// Chinese explanation (中文备注).
    public let zh: String

    public init(en: String, zh: String) {
        self.en = en
        self.zh = zh
    }

    /// Returns the annotation in the requested language.
    public func text(for language: NoteLanguage) -> String {
        switch language {
        case .english: return en
        case .chinese: return zh
        }
    }
}

/// A single metadata field extracted from a media file.
///
/// The design mirrors the philosophy of `exiftool -G1 -s`: every item keeps
/// the raw container key, a formatted value, and is grouped by its metadata
/// family (EXIF, TIFF, GPS, QuickTime, ID3, ...).
public struct MetadataItem: Identifiable, Hashable, Sendable {
    public let id: UUID

    /// Raw key exactly as stored in the container, e.g. `DateTimeOriginal`.
    public let key: String

    /// Human friendly display name derived from the raw key,
    /// e.g. `Date Time Original`.
    public let name: String

    /// Formatted, display-ready value (e.g. `1/920 s` instead of `0.001087`).
    public let value: String

    /// Bilingual explanation for well-known fields.
    ///
    /// Deliberately `nil` for unknown or uncommon fields: those are displayed
    /// "as-is" without any annotation.
    public let note: FieldNote?

    public init(key: String, name: String? = nil, value: String, note: FieldNote? = nil) {
        self.id = UUID()
        self.key = key
        self.name = name ?? MetadataItem.humanize(key)
        self.value = value
        self.note = note
    }

    /// Converts a camel-cased container key into a human readable title.
    ///
    /// Examples:
    ///   - `DateTimeOriginal`      -> `Date Time Original`
    ///   - `FNumber`               -> `F Number`
    ///   - `GPSHPositioningError`  -> `GPSH Positioning Error`
    ///   - `com.apple.quicktime.make` -> `Make` (prefix stripped by callers)
    public static func humanize(_ key: String) -> String {
        guard !key.isEmpty else { return key }
        let chars = Array(key)
        var result = ""
        result.reserveCapacity(key.count + 4)
        for (i, c) in chars.enumerated() where i > 0 {
            if c.isUppercase {
                let prev = chars[i - 1]
                let nextIsLower = (i + 1 < chars.count) ? chars[i + 1].isLowercase : false
                // Break on lower->upper transitions ("Time|Original") and at the
                // end of an acronym run ("XML|Parser").
                if prev.isLowercase || prev.isNumber || (prev.isUppercase && nextIsLower) {
                    result.append(" ")
                }
            }
            result.append(c)
        }
        // Also add the very first character.
        return String(key.first!) + result
    }
}

/// A named collection of metadata items, e.g. `EXIF`, `GPS` or `Video Track 1`.
public struct MetadataGroup: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public var items: [MetadataItem]

    public init(name: String, items: [MetadataItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
    }
}

/// The kind of media a document represents, used for iconography in the UI.
public enum MediaKind: String, Sendable {
    case image
    case video
    case audio
    case other
}

/// The complete extraction result for one file.
public struct MetadataDocument: Sendable {
    /// The file that was inspected.
    public let fileURL: URL

    /// File size in bytes (duplicated here so the UI/CLI need no extra I/O).
    public let fileSize: Int64

    /// Uniform type identifier of the file, if determinable.
    public let contentType: UTType?

    /// Broad media classification of the file.
    public let kind: MediaKind

    /// Extracted metadata, in display order.
    public let groups: [MetadataGroup]

    public init(fileURL: URL, fileSize: Int64, contentType: UTType?, kind: MediaKind, groups: [MetadataGroup]) {
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.contentType = contentType
        self.kind = kind
        self.groups = groups
    }

    /// Total number of metadata items across all groups.
    public var itemCount: Int {
        groups.reduce(0) { $0 + $1.items.count }
    }

    /// Convenience lookup used for the summary chips in the UI header.
    /// Returns the formatted value of the first item with one of `keys`.
    public func firstValue(forKeys keys: [String]) -> String? {
        for group in groups {
            for item in group.items where keys.contains(item.key) {
                return item.value
            }
        }
        return nil
    }

    /// Renders the whole document in an `exiftool -G1 -s` inspired text form.
    /// Used by the CLI dump mode and by the "Copy All" feature.
    public func plainTextReport() -> String {
        // Column width for the "[Group]" prefix, exiftool style.
        var lines: [String] = []
        lines.append("File: \(fileURL.path)")
        for group in groups where !group.items.isEmpty {
            let tagWidth = group.items.map(\.key.count).max() ?? 0
            // padding(toLength:) truncates strings longer than the target,
            // so clamp the width (long track group names must survive).
            let groupLabel = "[\(group.name)]"
            let groupWidth = max(22, groupLabel.count)
            for item in group.items {
                let paddedGroup = groupLabel.padding(toLength: groupWidth, withPad: " ", startingAt: 0)
                let paddedKey = item.key.padding(toLength: tagWidth, withPad: " ", startingAt: 0)
                lines.append("\(paddedGroup) \(paddedKey) : \(item.value)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// JSON representation used by the Export feature.
    ///
    /// Schema:
    /// ```
    /// {
    ///   "file": "<path>", "fileSize": <bytes>, "kind": "image|video|audio|other",
    ///   "groups": [
    ///     { "name": "EXIF",
    ///       "items": [ { "key": "FNumber", "value": "ƒ/1.8" }, ... ] },
    ///     ...
    ///   ]
    /// }
    /// ```
    ///
    /// Groups and items are *arrays*, not dictionaries keyed by name/key:
    /// real containers can legitimately produce duplicate group names (e.g.
    /// several QuickTime metadata formats mapping to the same label) and
    /// duplicate keys within one group (repeated ID3 frames or QuickTime
    /// keys). Arrays preserve every entry in display order, so the export is
    /// lossless relative to the on-screen report.
    public func jsonReport() throws -> Data {
        let groupsArray: [[String: Any]] = groups.map { group in
            [
                "name": group.name,
                "items": group.items.map { ["key": $0.key, "value": $0.value] }
            ]
        }
        let root: [String: Any] = [
            "file": fileURL.path,
            "fileSize": fileSize,
            "kind": kind.rawValue,
            "groups": groupsArray
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
}

/// Errors thrown by the extraction pipeline.
public enum ExtractionError: Error, LocalizedError {
    /// The file does not exist or cannot be opened.
    case unreadableFile(String)
    /// The file is readable but its format is not supported by any extractor.
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let path):
            return "Cannot read file: \(path)"
        case .unsupportedFormat(let path):
            return "Unsupported or unrecognized media format: \(path)"
        }
    }
}
