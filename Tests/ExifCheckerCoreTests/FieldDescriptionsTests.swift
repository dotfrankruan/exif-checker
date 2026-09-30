import XCTest
@testable import ExifCheckerCore

/// The annotation database: common fields must have bilingual notes, unknown
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

    func testCaseAliasesResolveDeterministically() {
        // EXIF spells it `SubSecTimeOriginal`, some containers deliver
        // `SubsecTimeOriginal`; both alias to the same note regardless of
        // dictionary iteration order.
        XCTAssertEqual(
            FieldDescriptions.note(forKey: "SubSecTimeOriginal"),
            FieldDescriptions.note(forKey: "SubsecTimeOriginal")
        )
        XCTAssertEqual(
            FieldDescriptions.note(forKey: "subsectimedigitized"),
            FieldDescriptions.note(forKey: "SubSecTimeDigitized")
        )
    }

    func testUnknownFieldReturnsNil() {
        XCTAssertNil(FieldDescriptions.note(forKey: "ThisKeyDoesNotExistAnywhere"))
    }

    func testNotesAreBilingual() {
        // Every annotation must ship an English and a Chinese variant.
        let note = FieldDescriptions.note(forKey: "Make")
        XCTAssertEqual(note?.en, "Device manufacturer.")
        XCTAssertEqual(note?.zh, "设备制造商。")
    }

    func testNoteLanguageSelection() {
        let note = FieldDescriptions.note(forKey: "GPSLatitude")
        XCTAssertEqual(note?.text(for: .english), "Latitude where the photo was taken.")
        XCTAssertEqual(note?.text(for: .chinese), "拍摄地纬度。")
    }
}
