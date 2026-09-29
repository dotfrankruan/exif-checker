import XCTest
@testable import ExifCheckerCore

/// Unit tests for the value formatting layer — the part that turns raw
/// container numbers into exiftool-style human readable values.
final class ValueFormatterTests: XCTestCase {

    // MARK: Exposure triangle

    func testExposureTimeBecomesFraction() {
        XCTAssertEqual(ValueFormatter.format(key: "ExposureTime", value: 1.0 / 920.0), "1/920 s")
        XCTAssertEqual(ValueFormatter.format(key: "ExposureTime", value: 2.5), "2.5 s")
    }

    func testApexShutterSpeed() {
        // APEX: 2^-9.84 s ≈ 1/917 s
        XCTAssertEqual(ValueFormatter.format(key: "ShutterSpeedValue", value: 9.84), "1/917 s")
    }

    func testApertureFormatting() {
        XCTAssertEqual(ValueFormatter.format(key: "FNumber", value: 1.78), "ƒ/1.78")
        // APEX aperture: 2^(1.6955/2) ≈ 1.8
        XCTAssertEqual(ValueFormatter.format(key: "ApertureValue", value: 1.6955), "ƒ/1.8")
    }

    func testFocalLength() {
        XCTAssertEqual(ValueFormatter.format(key: "FocalLength", value: 6.765), "6.765 mm")
        XCTAssertEqual(ValueFormatter.format(key: "FocalLenIn35mmFilm", value: 24), "24 mm")
    }

    func testISOArray() {
        XCTAssertEqual(ValueFormatter.format(key: "ISOSpeedRatings", value: [80]), "ISO 80")
    }

    func testExposureBias() {
        XCTAssertEqual(ValueFormatter.format(key: "ExposureBiasValue", value: 0), "0 EV")
        XCTAssertEqual(ValueFormatter.format(key: "ExposureBiasValue", value: -1.3), "-1.3 EV")
    }

    // MARK: Enum mappings

    func testOrientationEnum() {
        XCTAssertEqual(ValueFormatter.format(key: "Orientation", value: 1), "Horizontal (normal) (1)")
        XCTAssertEqual(ValueFormatter.format(key: "Orientation", value: 6), "Rotate 90° CW (6)")
    }

    func testMeteringModeEnum() {
        XCTAssertEqual(ValueFormatter.format(key: "MeteringMode", value: 5), "Multi-segment (5)")
    }

    func testUnknownEnumValueStaysNumeric() {
        XCTAssertEqual(ValueFormatter.format(key: "MeteringMode", value: 99), "99")
    }

    // MARK: Flash bitmask

    func testFlashOffDidNotFire() {
        XCTAssertEqual(ValueFormatter.format(key: "Flash", value: 16), "Off, Did not fire (16)")
    }

    func testFlashFiredAuto() {
        // 0b11001: fired + auto mode, no strobe-return information.
        XCTAssertEqual(ValueFormatter.format(key: "Flash", value: 25), "Auto, Fired (25)")
    }

    // MARK: GPS

    func testGPSLatitudeDMS() {
        let siblings: [String: Any] = ["GPSLatitudeRef": "N"]
        let formatted = ValueFormatter.format(key: "GPSLatitude", value: 48.8584, siblings: siblings)
        XCTAssertEqual(formatted, "48° 51' 30.24\" N")
    }

    func testGPSAltitudeWithRef() {
        let siblings: [String: Any] = ["GPSAltitudeRef": 0]
        XCTAssertEqual(
            ValueFormatter.format(key: "GPSAltitude", value: 11.1, siblings: siblings),
            "11.1 m Above Sea Level"
        )
    }

    // MARK: Versions and lens range

    func testVersionArray() {
        XCTAssertEqual(ValueFormatter.format(key: "ExifVersion", value: [2, 3, 2]), "2.3.2")
    }

    func testLensSpecification() {
        let spec: [Any] = [2.220000029, 16.890625, 1.779999971, 2.798828125]
        XCTAssertEqual(ValueFormatter.format(key: "LensSpecification", value: spec), "2.22-16.9 mm, ƒ/1.78-2.8")
    }

    // MARK: Generic describe

    func testDescribeBinaryData() {
        XCTAssertEqual(ValueFormatter.describe(Data(count: 42)), "<binary data, 42 bytes>")
    }

    func testDescribeBoolean() {
        XCTAssertEqual(ValueFormatter.describe(NSNumber(value: true)), "Yes")
    }

    func testDescribeArray() {
        XCTAssertEqual(ValueFormatter.describe([1, "a", 2.5]), "1, a, 2.5")
    }

    // MARK: Numeric helpers

    func testDurationString() {
        XCTAssertEqual(ValueFormatter.durationString(seconds: 2.133), "2.13 s")
        XCTAssertEqual(ValueFormatter.durationString(seconds: 65.5), "1:05.50")
        XCTAssertEqual(ValueFormatter.durationString(seconds: 3723.0), "1:02:03.00")
    }

    func testBitRateString() {
        XCTAssertEqual(ValueFormatter.bitRateString(bitsPerSecond: 13_265_606), "13.3 Mb/s")
        XCTAssertEqual(ValueFormatter.bitRateString(bitsPerSecond: 128_000), "128 kb/s")
    }

    // MARK: Key humanization

    func testHumanize() {
        XCTAssertEqual(MetadataItem.humanize("DateTimeOriginal"), "Date Time Original")
        XCTAssertEqual(MetadataItem.humanize("FNumber"), "F Number")
        XCTAssertEqual(MetadataItem.humanize("GPSLatitude"), "GPS Latitude")
        XCTAssertEqual(MetadataItem.humanize("ISOSpeedRatings"), "ISO Speed Ratings")
    }
}
