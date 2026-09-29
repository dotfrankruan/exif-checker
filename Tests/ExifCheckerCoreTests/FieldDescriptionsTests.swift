import XCTest
@testable import ExifCheckerCore

/// The annotation database: common fields must have Chinese notes, unknown
/// fields must return nil (leave as-is), and lookup must tolerate the case
/// differences between EXIF (`CreationDate`) and QuickTime (`Creationdate`).
final class FieldDescriptionsTests: XCTestCase {

    func testCommonFieldsHaveNotes() {
        XCTAssertNotNil(FieldDescriptions.note(forKey: "Make"))
        XCTAssertNotNil(FieldDescriptions.note(forKey: "ExposureTime"))
        XCTAssertNotNil(FieldDescriptions.note(forKey: "GPSLatitude"))
        XCTAssertNotNil(FieldDescriptions.note(forKey: "Duration"))
        XCTAssertNotNil(FieldDescriptions.note(forKey: "Codec"))
    }

    func testCaseInsensitiveLookup() {
        XCTAssertNotNil(FieldDescriptions.note(forKey: "creationdate"))
        XCTAssertNotNil(FieldDescriptions.note(forKey: "Creationdate"))
    }

    func testUnknownFieldReturnsNil() {
        XCTAssertNil(FieldDescriptions.note(forKey: "ThisKeyDoesNotExistAnywhere"))
    }

    func testNotesAreChinese() {
        // Spot check that annotations are actually Chinese explanations.
        let note = FieldDescriptions.note(forKey: "Make")
        XCTAssertEqual(note, "设备制造商。")
    }
}
