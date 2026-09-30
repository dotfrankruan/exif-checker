import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ExifCheckerCore

/// End-to-end extraction tests using fixture files generated in-memory:
///   - a JPEG with synthetic EXIF/TIFF/GPS dictionaries (ImageIO path);
///   - a minimal PCM WAV file (AVFoundation audio path).
final class ExtractionTests: XCTestCase {

    // MARK: - Image pipeline

    func testJPEGExtraction() async throws {
        let url = try makeJPEGFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await MetadataLoader.load(from: url)
        XCTAssertEqual(document.kind, .image)

        // File system group is always present.
        XCTAssertNotNil(document.groups.first { $0.name == "File System" })

        let exif = try XCTUnwrap(document.groups.first { $0.name == "EXIF" })
        XCTAssertEqual(value(of: "DateTimeOriginal", in: exif), "2026:09:29 12:29:19")
        XCTAssertEqual(value(of: "FNumber", in: exif), "ƒ/1.8")
        XCTAssertEqual(value(of: "ExposureTime", in: exif), "1/920 s")
        // Well-known keys carry Chinese annotations.
        XCTAssertNotNil(item("Make", in: try XCTUnwrap(document.groups.first { $0.name == "TIFF" }))?.note)

        // GPS keys are re-prefixed and formatted as DMS with hemisphere.
        let gps = try XCTUnwrap(document.groups.first { $0.name == "GPS" })
        XCTAssertEqual(value(of: "GPSLatitude", in: gps), "48° 51' 30.24\" N")
    }

    // MARK: - Audio pipeline

    func testWAVExtraction() async throws {
        let url = try makeWAVFixture(durationSeconds: 0.25, sampleRate: 8000)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try await MetadataLoader.load(from: url)
        XCTAssertEqual(document.kind, .audio)

        let general = try XCTUnwrap(document.groups.first { $0.name == "General" })
        XCTAssertEqual(value(of: "Duration", in: general), "0.25 s")

        let audioTrack = try XCTUnwrap(document.groups.first { $0.name.hasPrefix("Audio Track") })
        XCTAssertEqual(value(of: "Codec", in: audioTrack), "Linear PCM (lpcm)")
        XCTAssertEqual(value(of: "SampleRate", in: audioTrack), "8000 Hz")
        XCTAssertEqual(value(of: "Channels", in: audioTrack), "1")
        XCTAssertEqual(value(of: "BitsPerChannel", in: audioTrack), "16")
    }

    // MARK: - Error handling

    func testMissingFileThrows() async {
        let url = URL(fileURLWithPath: "/nonexistent/path/nowhere.jpg")
        await assertUnreadableFile(url)
    }

    /// A directory "exists", so a bare existence check would accept it;
    /// the loader must reject it before any extractor runs.
    func testDirectoryThrows() async {
        await assertUnreadableFile(FileManager.default.temporaryDirectory)
    }

    /// Existence plus regular-file is not enough: permission-less files
    /// must be rejected as unreadable too.
    func testUnreadableFileThrows() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("exifchecker-test-\(UUID().uuidString).jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xE0]).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        defer {
            // Restore permissions so the fixture can be cleaned up.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        await assertUnreadableFile(url)
    }

    /// Asserts that loading `url` throws `ExtractionError.unreadableFile`.
    private func assertUnreadableFile(_ url: URL) async {
        do {
            _ = try await MetadataLoader.load(from: url)
            XCTFail("Expected ExtractionError.unreadableFile for \(url.path)")
        } catch let error as ExtractionError {
            guard case .unreadableFile = error else {
                return XCTFail("Expected .unreadableFile, got \(error)")
            }
        } catch {
            XCTFail("Expected ExtractionError, got \(error)")
        }
    }

    // MARK: - Fixtures

    /// Creates a small JPEG with synthetic EXIF/TIFF/GPS metadata.
    private func makeJPEGFixture() throws -> URL {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 8, height: 6,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())

        let properties: [String: Any] = [
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Apple",
                kCGImagePropertyTIFFModel as String: "Unit Test Camera"
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2026:09:29 12:29:19",
                kCGImagePropertyExifFNumber as String: 1.8,
                kCGImagePropertyExifExposureTime as String: 1.0 / 920.0
            ],
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 48.8584,
                kCGImagePropertyGPSLatitudeRef as String: "N"
            ]
        ]

        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ExtractionError.unreadableFile("failed to finalize JPEG fixture")
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("exifchecker-test-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Creates a minimal 16-bit mono PCM WAV file.
    private func makeWAVFixture(durationSeconds: Double, sampleRate: UInt32) throws -> URL {
        let bytesPerFrame: UInt32 = 2 // 16-bit mono
        let frames = UInt32(Double(sampleRate) * durationSeconds)
        let dataSize = frames * bytesPerFrame

        var data = Data()
        func appendASCII(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: UInt32) { var v = value.littleEndian; data.append(Data(bytes: &v, count: 4)) }
        func append16(_ value: UInt16) { var v = value.littleEndian; data.append(Data(bytes: &v, count: 2)) }

        // Canonical 44-byte RIFF/WAVE header.
        appendASCII("RIFF"); append32(36 + dataSize); appendASCII("WAVE")
        appendASCII("fmt "); append32(16)
        append16(1)                      // PCM
        append16(1)                      // mono
        append32(sampleRate)
        append32(sampleRate * bytesPerFrame) // byte rate
        append16(UInt16(bytesPerFrame))      // block align
        append16(16)                     // bits per sample
        appendASCII("data"); append32(dataSize)
        data.append(Data(count: Int(dataSize))) // silence

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("exifchecker-test-\(UUID().uuidString).wav")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Assertions helpers

    private func item(_ key: String, in group: MetadataGroup) -> MetadataItem? {
        group.items.first { $0.key == key }
    }

    private func value(of key: String, in group: MetadataGroup) -> String? {
        item(key, in: group)?.value
    }
}
