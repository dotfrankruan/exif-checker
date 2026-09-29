import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Extracts metadata from still images using ImageIO.
///
/// ImageIO covers JPEG, HEIC/HEIF, PNG, GIF, TIFF, DNG, WebP and more, and
/// exposes the embedded metadata as nested dictionaries:
/// top-level image properties plus `{TIFF}`, `{Exif}`, `{ExifAux}`, `{GPS}`,
/// `{IPTC}`, `{MakerApple}` and friends — the same information `exiftool`
/// reports for photos.
public enum ImageMetadataExtractor {

    /// Returns `true` when ImageIO recognizes the file as a still image.
    public static func canHandle(url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let typeIdentifier = CGImageSourceGetType(source) as String?,
              let type = UTType(typeIdentifier) else {
            return false
        }
        return type.conforms(to: .image)
    }

    /// Extracts all metadata groups of the image. Returns an empty array when
    /// the file cannot be interpreted as an image.
    public static func extract(from url: URL) -> [MetadataGroup] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
        var groups: [MetadataGroup] = []

        // MARK: Top level "Image" group (pixel size, color model, ...)
        var imageBuilder = GroupBuilder(name: "Image")

        if let typeIdentifier = CGImageSourceGetType(source) as String? {
            let type = UTType(typeIdentifier)
            let formatName = type?.localizedDescription ?? typeIdentifier
            imageBuilder.addFormatted("ImageFormat", formatName)
        }
        let imageCount = CGImageSourceGetCount(source)
        if imageCount > 1 {
            // Animated GIF / multi-page TIFF / burst HEIC.
            imageBuilder.addFormatted("ImageCount", "\(imageCount)")
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            groups.append(imageBuilder.group)
            return groups
        }

        // Scalar top-level keys describe the image itself; dictionary values
        // are metadata families and become their own groups below.
        for key in properties.keys.sorted() {
            guard let value = properties[key], !(value is [String: Any]) else { continue }
            imageBuilder.add(key, value)
        }
        groups.append(imageBuilder.group)

        // MARK: Known metadata sub-dictionaries
        for (rawKey, groupName) in subDictionaryMapping {
            guard let dictionary = properties[rawKey] as? [String: Any], !dictionary.isEmpty else { continue }

            if groupName == "GPS" {
                // ImageIO stores GPS keys without the "GPS" prefix
                // ("Latitude", "AltitudeRef", ...). Re-prefix them so they
                // match exiftool's names and the annotation database, e.g.
                // "Latitude" -> "GPSLatitude".
                var prefixed: [String: Any] = [:]
                for (key, value) in dictionary {
                    prefixed[key.hasPrefix("GPS") ? key : "GPS" + key] = value
                }
                var builder = GroupBuilder(name: groupName, siblings: prefixed)
                builder.addAll(prefixed)
                groups.append(builder.group)
            } else {
                var builder = GroupBuilder(name: groupName, siblings: dictionary)
                builder.addAll(dictionary)
                groups.append(builder.group)
            }
        }

        return groups
    }

    /// Maps ImageIO's sub-dictionary keys to display group names, in the
    /// order they should appear. EXIF-style groups come first because they
    /// carry the most interesting photographic information.
    private static let subDictionaryMapping: [(String, String)] = [
        (kCGImagePropertyTIFFDictionary as String, "TIFF"),
        (kCGImagePropertyExifDictionary as String, "EXIF"),
        (kCGImagePropertyExifAuxDictionary as String, "EXIF Aux"),
        (kCGImagePropertyGPSDictionary as String, "GPS"),
        (kCGImagePropertyIPTCDictionary as String, "IPTC"),
        (kCGImagePropertyMakerAppleDictionary as String, "Maker Notes (Apple)"),
        (kCGImagePropertyJFIFDictionary as String, "JFIF"),
        (kCGImagePropertyPNGDictionary as String, "PNG"),
        (kCGImagePropertyGIFDictionary as String, "GIF"),
        (kCGImagePropertyDNGDictionary as String, "DNG"),
        (kCGImageProperty8BIMDictionary as String, "Photoshop"),
        (kCGImagePropertyOpenEXRDictionary as String, "OpenEXR"),
        (kCGImagePropertyFileContentsDictionary as String, "File Contents")
    ]
}
