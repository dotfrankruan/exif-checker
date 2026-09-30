import XCTest
@testable import ExifCheckerCore

/// Tests for the report/export layer of ``MetadataDocument`` (plain text +
/// JSON) and for ``GroupBuilder`` ordering. Everything here is pure model
/// code — no file I/O, no framework callbacks — so results are fully
/// deterministic.
final class ReportTests: XCTestCase {

    // MARK: - JSON export fidelity

    /// Real containers legitimately produce duplicate group names (several
    /// metadata formats sharing one label) and duplicate keys within a group
    /// (repeated ID3 frames / QuickTime keys). The JSON export must keep
    /// every entry instead of silently overwriting them.
    func testJSONReportPreservesDuplicateGroupsAndKeys() throws {
        let document = MetadataDocument(
            fileURL: URL(fileURLWithPath: "/tmp/sample.mov"),
            fileSize: 42,
            contentType: nil,
            kind: .video,
            groups: [
                MetadataGroup(name: "QuickTime Metadata", items: [
                    MetadataItem(key: "Make", value: "Apple"),
                    MetadataItem(key: "Make", value: "Apple Duplicate")
                ]),
                MetadataGroup(name: "QuickTime Metadata", items: [
                    MetadataItem(key: "Model", value: "iPhone")
                ])
            ]
        )

        let root = try parseJSON(try document.jsonReport())
        XCTAssertEqual(root["file"] as? String, "/tmp/sample.mov")
        XCTAssertEqual(root["fileSize"] as? Int64, 42)
        XCTAssertEqual(root["kind"] as? String, "video")

        let groups = try XCTUnwrap(root["groups"] as? [[String: Any]])
        XCTAssertEqual(groups.count, 2, "duplicate group names must not collapse")

        let firstItems = try XCTUnwrap(groups[0]["items"] as? [[String: String]])
        XCTAssertEqual(firstItems.count, 2, "duplicate keys must not collapse")
        XCTAssertEqual(firstItems.map { $0["key"] }, ["Make", "Make"])
        XCTAssertEqual(firstItems.map { $0["value"] }, ["Apple", "Apple Duplicate"])

        XCTAssertEqual(groups[0]["name"] as? String, "QuickTime Metadata")
        XCTAssertEqual(groups[1]["name"] as? String, "QuickTime Metadata")
    }

    /// Group order in the JSON must match display order (arrays, not a
    /// name-keyed dictionary, are what guarantees this).
    func testJSONReportPreservesGroupOrder() throws {
        let names = ["File System", "General", "Video Track 1", "Audio Track 2"]
        let document = MetadataDocument(
            fileURL: URL(fileURLWithPath: "/tmp/x.mov"),
            fileSize: 1,
            contentType: nil,
            kind: .video,
            groups: names.map { MetadataGroup(name: $0) }
        )
        let root = try parseJSON(try document.jsonReport())
        let groups = try XCTUnwrap(root["groups"] as? [[String: Any]])
        XCTAssertEqual(groups.compactMap { $0["name"] as? String }, names)
    }

    // MARK: - Plain text report

    /// `padding(toLength:)` truncates strings longer than the target width;
    /// the report must clamp widths so long group names and keys survive.
    func testPlainTextReportKeepsLongNamesAndKeysUntruncated() {
        let longName = "A Group Name That Is Definitely Longer Than Twenty-Two"
        let longKey = "AVeryLongContainerKeyThatKeepsGoing"
        let document = MetadataDocument(
            fileURL: URL(fileURLWithPath: "/tmp/x.jpg"),
            fileSize: 1,
            contentType: nil,
            kind: .image,
            groups: [
                MetadataGroup(name: longName, items: [
                    MetadataItem(key: longKey, value: "v")
                ])
            ]
        )
        let report = document.plainTextReport()
        XCTAssertTrue(report.contains("[\(longName)]"), "long group name was truncated:\n\(report)")
        XCTAssertTrue(report.contains(longKey), "long key was truncated:\n\(report)")
        XCTAssertTrue(report.hasPrefix("File: /tmp/x.jpg"))
    }

    /// Both duplicate rows appear in the plain text report as well.
    func testPlainTextReportKeepsDuplicateKeys() {
        let document = MetadataDocument(
            fileURL: URL(fileURLWithPath: "/tmp/x.mov"),
            fileSize: 1,
            contentType: nil,
            kind: .video,
            groups: [
                MetadataGroup(name: "ID3 Metadata", items: [
                    MetadataItem(key: "Comment", value: "first"),
                    MetadataItem(key: "Comment", value: "second")
                ])
            ]
        )
        let report = document.plainTextReport()
        XCTAssertTrue(report.contains("first"))
        XCTAssertTrue(report.contains("second"))
    }

    // MARK: - GroupBuilder ordering

    /// Natural (Finder-style) ordering: numeric runs compare numerically,
    /// so Maker-Notes-style keys sort 1, 2, 10, 20 — not 1, 10, 2, 20.
    func testGroupBuilderNaturalSortOrder() {
        var builder = GroupBuilder(name: "Maker Notes (Apple)")
        builder.addAll(["20": "a", "10": "b", "2": "c", "1": "d"])
        XCTAssertEqual(builder.group.items.map(\.key), ["1", "2", "10", "20"])
    }

    /// `nil` values must never produce rows.
    func testGroupBuilderSkipsNilValues() {
        var builder = GroupBuilder(name: "EXIF")
        builder.add("Present", "yes")
        builder.add("Absent", nil)
        XCTAssertEqual(builder.group.items.map(\.key), ["Present"])
    }

    // MARK: - Key humanization

    func testHumanizeAcronymBoundaries() {
        XCTAssertEqual(MetadataItem.humanize("XMLParser"), "XML Parser")
        XCTAssertEqual(MetadataItem.humanize("GPSHPositioningError"), "GPSH Positioning Error")
        XCTAssertEqual(MetadataItem.humanize(""), "")
    }

    // MARK: - Helpers

    private func parseJSON(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
