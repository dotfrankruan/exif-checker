import Foundation

/// Incrementally builds a ``MetadataGroup`` from raw container values.
///
/// Responsibilities:
///   - skip `nil` values so absent fields never produce rows;
///   - run every value through ``ValueFormatter`` (key-aware formatting);
///   - attach the localized annotation from ``FieldDescriptions`` when the
///     field is well-known (unknown fields stay without a note);
///   - hand sibling values to the formatter for composite presentations
///     (e.g. `GPSLatitude` needs `GPSLatitudeRef`).
public struct GroupBuilder {
    public private(set) var group: MetadataGroup

    /// The raw values of the group being built, used as formatter context.
    private let siblings: [String: Any]

    public init(name: String, siblings: [String: Any] = [:]) {
        self.group = MetadataGroup(name: name)
        self.siblings = siblings
    }

    /// Adds a single item. `nil` values are silently skipped.
    /// - Parameters:
    ///   - key: the (already normalized) container key, e.g. `Make`.
    ///   - value: the raw value as returned by ImageIO / AVFoundation.
    ///   - sortFirst: reserved for future ordering needs.
    public mutating func add(_ key: String, _ value: Any?) {
        guard let value else { return }
        let formatted = ValueFormatter.format(key: key, value: value, siblings: siblings)
        let item = MetadataItem(key: key, value: formatted, note: FieldDescriptions.note(forKey: key))
        group.items.append(item)
    }

    /// Adds a raw value verbatim, bypassing key-aware formatting but still
    /// attaching a field description when one exists. Useful when the caller
    /// already produced a display string (e.g. computed bit rates).
    public mutating func addFormatted(_ key: String, _ displayValue: String) {
        let item = MetadataItem(key: key, value: displayValue, note: FieldDescriptions.note(forKey: key))
        group.items.append(item)
    }

    /// Adds every entry of a raw dictionary, sorted by key for a stable,
    /// deterministic display order (container dictionaries are unordered).
    public mutating func addAll(_ dictionary: [String: Any]) {
        for key in dictionary.keys.sorted() {
            add(key, dictionary[key])
        }
    }

    /// Sorts the accumulated items alphabetically by raw key.
    public mutating func sortItems() {
        group.items.sort { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }
}
