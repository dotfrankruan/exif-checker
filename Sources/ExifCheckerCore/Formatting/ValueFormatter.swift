import Foundation

/// Converts raw container values into human readable display strings.
///
/// Two levels of formatting exist:
///
///   1. ``describe(_:)`` — a generic, lossless rendering of any
///      property-list-ish value (numbers, dates, arrays, data, ...).
///   2. ``format(key:value:siblings:)`` — key-aware smart formatting for
///      well-known EXIF / GPS / QuickTime fields, inspired by the way
///      `exiftool` presents values (e.g. `1/920 s` instead of `0.001087`).
///
/// Unknown keys deliberately fall through to the generic rendering so their
/// values stay untouched ("leave it as-is").
public enum ValueFormatter {

    // MARK: - Public API

    /// Key-aware formatting. `siblings` carries the other raw values of the
    /// same metadata group, needed for composite presentations such as
    /// `GPSLatitude` + `GPSLatitudeRef`.
    public static func format(key: String, value: Any, siblings: [String: Any] = [:]) -> String {
        switch key {

        // MARK: Exposure triangle
        case "ExposureTime":
            // Stored in seconds; display as a shutter speed fraction.
            if let s = number(value) { return shutterSpeedString(seconds: s) }
        case "ShutterSpeedValue":
            // APEX: shutter speed in seconds = 2^-value.
            if let v = number(value) { return shutterSpeedString(seconds: pow(2.0, -v)) }
        case "ApertureValue", "MaxApertureValue":
            // APEX: f-number = 2^(value/2).
            if let v = number(value) { return apertureString(fNumber: pow(2.0, v / 2.0)) }
        case "FNumber":
            if let v = number(value) { return apertureString(fNumber: v) }
        case "FocalLength", "FocalLengthIn35mmFilmFormat", "FocalLenIn35mmFilm":
            // Note: ImageIO shortens the EXIF key to "FocalLenIn35mmFilm".
            if let v = number(value) { return "\(trimmed(v)) mm" }
        case "ISOSpeedRatings", "ISOSpeed":
            if let array = value as? [Any] {
                let iso = array.compactMap { ($0 as? NSNumber)?.stringValue }.joined(separator: ", ")
                return "ISO \(iso)"
            }
            if let v = number(value) { return "ISO \(trimmed(v))" }
        case "ExposureBiasValue":
            // Exposure compensation in EV; show an explicit sign like exiftool.
            if let v = number(value) {
                if v == 0 { return "0 EV" }
                return String(format: "%+.1f EV", v)
            }

        // MARK: GPS coordinates (need sibling refs)
        case "GPSLatitude", "GPSLongitude":
            if let v = number(value) {
                let refKey = (key == "GPSLatitude") ? "GPSLatitudeRef" : "GPSLongitudeRef"
                return dmsString(decimalDegrees: v, ref: siblings[refKey] as? String)
            }

        // MARK: Version blobs
        case "ExifVersion", "FlashpixVersion":
            // ImageIO delivers these as an array of numbers, e.g. [2, 3, 2].
            if let digits = value as? [Any] {
                return digits.map { describe($0) }.joined(separator: ".")
            }
        // MARK: Lens range
        case "LensSpecification":
            // [minFocal, maxFocal, minFNumber, maxFNumber]; round to 3
            // significant digits to match exiftool's presentation.
            if let values = (value as? [Any])?.compactMap(number), values.count == 4 {
                let g3 = { String(format: "%.3g", $0) }
                let focal = "\(g3(values[0]))-\(g3(values[1])) mm"
                let aperture = "ƒ/\(g3(values[2]))-\(g3(values[3]))"
                return "\(focal), \(aperture)"
            }

        // MARK: Bitmask / enum fields
        case "Flash":
            if let v = intValue(value) { return decodeFlash(v) }
        case "GPSAltitude":
            if let v = number(value) {
                let ref = intValue(siblings["GPSAltitudeRef"] ?? 0) ?? 0
                let suffix = ref == 1 ? "m Below Sea Level" : "m Above Sea Level"
                return "\(trimmed(v)) \(suffix)"
            }
        case "GPSSpeed":
            if let v = number(value) {
                let unit = (siblings["GPSSpeedRef"] as? String) ?? "K"
                let unitName = ["K": "km/h", "M": "mph", "N": "knots"][unit] ?? unit
                return "\(trimmed(v)) \(unitName)"
            }
        case "GPSImgDirection", "GPSDestBearing", "GPSTrack":
            if let v = number(value) { return String(format: "%.2f°", v) }
        case "GPSHPositioningError":
            if let v = number(value) { return "\(trimmed(v)) m" }

        // MARK: Integer enum lookups
        default:
            if let mapping = enumMappings[key], let v = intValue(value), let text = mapping[v] {
                return "\(text) (\(v))"
            }
        }
        // Unknown key or non-numeric value: leave it as-is.
        return describe(value)
    }

    /// Generic, lossless rendering of any property-list-ish value.
    public static func describe(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let bool as Bool where isCFBoolean(value):
            return bool ? "Yes" : "No"
        case let number as NSNumber:
            return formatNumber(number)
        case let date as Date:
            return dateFormatter.string(from: date)
        case let url as URL:
            return url.path
        case let data as Data:
            return "<binary data, \(data.count) bytes>"
        case let array as [Any]:
            return array.map { describe($0) }.joined(separator: ", ")
        case let dict as [String: Any]:
            // Compact rendering for rare nested dictionaries.
            let body = dict.keys.sorted().map { "\($0)=\(describe(dict[$0] ?? ""))" }.joined(separator: "; ")
            return "{\(body)}"
        default:
            return String(describing: value)
        }
    }

    // MARK: - Number helpers

    /// Extracts a `Double` from NSNumber/String like values.
    public static func number(_ value: Any) -> Double? {
        switch value {
        case let n as NSNumber:
            return n.doubleValue
        case let s as String:
            return Double(s)
        default:
            return nil
        }
    }

    /// Extracts an `Int` from NSNumber/String like values.
    public static func intValue(_ value: Any) -> Int? {
        switch value {
        case let n as NSNumber:
            return n.intValue
        case let s as String:
            return Int(s)
        default:
            return nil
        }
    }

    /// Trims a floating point number for display: integral values lose the
    /// fraction, everything else keeps up to 6 significant digits.
    public static func trimmed(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(format: "%.6g", value)
    }

    /// Formats a shutter speed given in seconds the way photographers expect:
    /// values below one second become fractions (`1/920 s`).
    public static func shutterSpeedString(seconds: Double) -> String {
        if seconds > 0 && seconds < 1 {
            return "1/\(Int((1.0 / seconds).rounded())) s"
        }
        return "\(trimmed(seconds)) s"
    }

    /// Formats an f-number (`1.8` -> `ƒ/1.8`).
    public static func apertureString(fNumber: Double) -> String {
        return "ƒ/\(String(format: "%.4g", fNumber))"
    }

    /// Formats a bit rate in bits per second (`13265606` -> `13.3 Mb/s`).
    public static func bitRateString(bitsPerSecond: Double) -> String {
        switch bitsPerSecond {
        case 1_000_000...:
            return String(format: "%.1f Mb/s", bitsPerSecond / 1e6)
        case 1_000...:
            return String(format: "%.0f kb/s", bitsPerSecond / 1e3)
        default:
            return String(format: "%.0f b/s", bitsPerSecond)
        }
    }

    /// Formats a duration in seconds: `2.13 s` for short clips,
    /// `1:23:45.67` for longer ones.
    public static func durationString(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "\(seconds)" }
        if seconds < 60 {
            return String(format: "%.2f s", seconds)
        }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = seconds - Double(totalSeconds / 60 * 60)
        if hours > 0 {
            return String(format: "%d:%02d:%05.2f", hours, minutes, secs)
        }
        return String(format: "%d:%05.2f", minutes, secs)
    }

    /// Formats a byte count using the platform's localized byte formatter,
    /// keeping the exact number of bytes in parentheses. For tiny files the
    /// human string already *is* the exact count ("70 bytes"), so the
    /// parenthesized duplicate is suppressed.
    public static func byteCountString(_ bytes: Int64) -> String {
        let human = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        let exact = NumberFormatter.localizedString(from: NSNumber(value: bytes), number: .decimal)
        return human == "\(exact) bytes" ? human : "\(human) (\(exact) bytes)"
    }

    /// Converts decimal degrees to the classic degrees/minutes/seconds form
    /// used by exiftool: `48° 51' 30.24" N`.
    public static func dmsString(decimalDegrees: Double, ref: String?) -> String {
        let absolute = abs(decimalDegrees)
        var degrees = Int(absolute)
        let minutesFull = (absolute - Double(degrees)) * 60.0
        var minutes = Int(minutesFull)
        var seconds = ((minutesFull - Double(minutes)) * 60.0 * 100).rounded() / 100
        if seconds >= 60 {
            seconds = 0
            minutes += 1
        }
        if minutes >= 60 {
            minutes = 0
            degrees += 1
        }
        let hemisphere: String
        if let ref, !ref.isEmpty {
            // ImageIO already provides single letter refs ("N", "S", "E", "W").
            hemisphere = String(ref.prefix(1)).uppercased()
        } else {
            hemisphere = ""
        }
        let base = String(format: "%d° %d' %.2f\"", degrees, minutes, seconds)
        if hemisphere.isEmpty {
            return decimalDegrees < 0 ? "-\(base)" : base
        }
        return "\(base) \(hemisphere)"
    }

    // MARK: - Private helpers

    /// NSNumber bridges both booleans and numbers; this distinguishes them.
    private static func isCFBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func formatNumber(_ number: NSNumber) -> String {
        // Objective-C type "c" is a boolean stored as NSNumber.
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "Yes" : "No"
        }
        let double = number.doubleValue
        if double == double.rounded() && abs(double) < 1e15 {
            return String(format: "%lld", number.int64Value)
        }
        return String(format: "%.10g", double)
    }

    /// Shared date formatter (formatters are expensive to create).
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - EXIF flash bitmask decoding

    /// Decodes the EXIF `Flash` bit field (see EXIF 2.3 specification) into a
    /// human readable summary, e.g. `Off, Did not fire`.
    static func decodeFlash(_ value: Int) -> String {
        var parts: [String] = []
        let fired = (value & 0x01) != 0
        let mode = (value >> 3) & 0x03

        // Mode first, matching exiftool's phrasing ("Off, Did not fire").
        if (value & 0x20) != 0 {
            parts.append("No flash function")
        } else {
            switch mode {
            case 1: parts.append("On")
            case 2: parts.append("Off")
            case 3: parts.append("Auto")
            default: break
            }
        }
        parts.append(fired ? "Fired" : "Did not fire")

        switch (value >> 1) & 0x03 {
        case 2: parts.append("Return not detected")
        case 3: parts.append("Return detected")
        default: break
        }
        if (value & 0x40) != 0 {
            parts.append("Red-eye reduction")
        }
        return parts.joined(separator: ", ") + " (\(value))"
    }

    // MARK: - EXIF enum mappings

    /// Integer enumerations defined by the EXIF/TIFF specification, keyed by
    /// the container key. Unknown values fall through to the raw number.
    static let enumMappings: [String: [Int: String]] = [
        "Orientation": [
            1: "Horizontal (normal)",
            2: "Mirror horizontal",
            3: "Rotate 180",
            4: "Mirror vertical",
            5: "Mirror horizontal and rotate 270° CW",
            6: "Rotate 90° CW",
            7: "Mirror horizontal and rotate 90° CW",
            8: "Rotate 270° CW"
        ],
        "ExposureProgram": [
            0: "Not defined",
            1: "Manual",
            2: "Program AE",
            3: "Aperture-priority AE",
            4: "Shutter speed priority AE",
            5: "Creative (slow speed)",
            6: "Action (high speed)",
            7: "Portrait",
            8: "Landscape",
            9: "Bulb"
        ],
        "MeteringMode": [
            0: "Unknown",
            1: "Average",
            2: "Center-weighted average",
            3: "Spot",
            4: "Multi-spot",
            5: "Multi-segment",
            6: "Partial",
            255: "Other"
        ],
        "LightSource": [
            0: "Unknown",
            1: "Daylight",
            2: "Fluorescent",
            3: "Tungsten (incandescent)",
            4: "Flash",
            9: "Fine weather",
            10: "Cloudy",
            11: "Shade",
            12: "Daylight fluorescent",
            13: "Day white fluorescent",
            14: "Cool white fluorescent",
            15: "White fluorescent",
            17: "Standard light A",
            18: "Standard light B",
            19: "Standard light C",
            20: "D55",
            21: "D65",
            22: "D75",
            23: "D50",
            24: "ISO studio tungsten",
            255: "Other"
        ],
        "ColorSpace": [
            1: "sRGB",
            0xFFFF: "Uncalibrated"
        ],
        "ExposureMode": [
            0: "Auto",
            1: "Manual",
            2: "Auto bracket"
        ],
        "WhiteBalance": [
            0: "Auto",
            1: "Manual"
        ],
        "SceneCaptureType": [
            0: "Standard",
            1: "Landscape",
            2: "Portrait",
            3: "Night"
        ],
        "GainControl": [
            0: "None",
            1: "Low gain up",
            2: "High gain up",
            3: "Low gain down",
            4: "High gain down"
        ],
        "Contrast": [
            0: "Normal",
            1: "Low",
            2: "High"
        ],
        "Saturation": [
            0: "Normal",
            1: "Low",
            2: "High"
        ],
        "Sharpness": [
            0: "Normal",
            1: "Soft",
            2: "Hard"
        ],
        "SensingMethod": [
            1: "Not defined",
            2: "One-chip color area",
            3: "Two-chip color area",
            4: "Three-chip color area",
            5: "Color sequential area",
            7: "Trilinear",
            8: "Color sequential linear"
        ],
        "SceneType": [
            1: "Directly photographed"
        ],
        "CustomRendered": [
            0: "Normal",
            1: "Custom"
        ],
        "ResolutionUnit": [
            1: "None",
            2: "inches",
            3: "cm"
        ],
        "YCbCrPositioning": [
            1: "Centered",
            2: "Co-sited"
        ],
        "CompositeImage": [
            0: "Unknown",
            1: "Not a composite image",
            2: "General composite image",
            3: "Composite image captured while shooting"
        ],
        "SubjectDistanceRange": [
            0: "Unknown",
            1: "Macro",
            2: "Close",
            3: "Distant"
        ],
        "GPSAltitudeRef": [
            0: "Above Sea Level",
            1: "Below Sea Level"
        ]
    ]
}
