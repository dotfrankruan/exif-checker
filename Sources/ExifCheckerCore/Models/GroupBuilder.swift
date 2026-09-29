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

    /// Adds every entry of a raw dictionary in natural key order
    /// (numeric runs compare numerically, so Maker Notes keys 1, 2, 10, 20
    /// stay in a sensible order).
    public mutating func addAll(_ dictionary: [String: Any]) {
        for key in dictionary.keys.sorted(by: GroupBuilder.naturalSort) {
            add(key, dictionary[key])
        }
    }

    /// Sorts the accumulated items by raw key in natural order.
    public mutating func sortItems() {
        group.items.sort(by: { GroupBuilder.naturalSort($0.key, $1.key) })
    }

    /// Finder-style natural comparison ("2" < "10"). Static so sorting
    /// `group.items` does not overlap accesses to `self`.
    private static func naturalSort(_ a: String, _ b: String) -> Bool {
        a.localizedStandardCompare(b) == .orderedAscending
    }
}
