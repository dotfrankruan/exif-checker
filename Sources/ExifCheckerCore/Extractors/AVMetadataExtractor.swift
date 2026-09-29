// `@preconcurrency` silences Sendable warnings for AVFoundation/CoreMedia
// types; all extraction happens sequentially inside nonisolated functions,
// so no value ever crosses an isolation boundary.
@preconcurrency import AVFoundation
import CoreAudio
import CoreMedia
import Foundation

/// Extracts metadata from audio/video files using AVFoundation — the same
/// domain `ffprobe` covers: container info, per-track codec details, and the
/// embedded metadata atoms (QuickTime keys, iTunes tags, ID3 frames).
public enum AVMetadataExtractor {

    /// Extracts all metadata groups of an audiovisual file. Returns an empty
    /// array when the file has neither tracks nor metadata (i.e. it is not a
    /// readable media container).
    public static func extract(from url: URL, fileSize: Int64) async -> [MetadataGroup] {
        let asset = AVURLAsset(url: url)

        let tracks = (try? await asset.load(.tracks)) ?? []
        let allMetadata = (try? await asset.load(.metadata)) ?? []
        guard !tracks.isEmpty || !allMetadata.isEmpty else { return [] }

        var groups: [MetadataGroup] = []
        if let general = await generalGroup(asset: asset, fileSize: fileSize) {
            groups.append(general)
        }
        for track in tracks {
            if let group = await trackGroup(track: track) {
                groups.append(group)
            }
        }
        groups.append(contentsOf: await metadataGroups(asset: asset))
        return groups
    }

    // MARK: - General container information

    /// Builds the "General" group: duration, overall bit rate, playability.
    private static func generalGroup(asset: AVAsset, fileSize: Int64) async -> MetadataGroup? {
        var builder = GroupBuilder(name: "General")

        if let duration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(duration)
            if seconds.isFinite, seconds > 0 {
                builder.addFormatted("Duration", ValueFormatter.durationString(seconds: seconds))
                if fileSize > 0 {
                    let bitsPerSecond = Double(fileSize) * 8.0 / seconds
                    builder.addFormatted("OverallBitRate", ValueFormatter.bitRateString(bitsPerSecond: bitsPerSecond))
                }
            }
        }
        if let playable = try? await asset.load(.isPlayable) {
            builder.addFormatted("IsPlayable", playable ? "Yes" : "No")
        }
        if let exportable = try? await asset.load(.isExportable) {
            builder.addFormatted("IsExportable", exportable ? "Yes" : "No")
        }
        if let rate = try? await asset.load(.preferredRate), rate != 0 {
            builder.addFormatted("PreferredRate", ValueFormatter.trimmed(Double(rate)))
        }
        if let volume = try? await asset.load(.preferredVolume) {
            builder.addFormatted("PreferredVolume", "\(Int((volume * 100).rounded()))%")
        }

        return builder.group.items.isEmpty ? nil : builder.group
    }

    // MARK: - Tracks

    /// Builds one group per track ("Video Track 1", "Audio Track 2", ...).
    private static func trackGroup(track: AVAssetTrack) async -> MetadataGroup? {
        let mediaType = track.mediaType
        let typeName = mediaTypeDisplayName(mediaType)
        var builder = GroupBuilder(name: "\(typeName) Track \(track.trackID)")

        builder.addFormatted("TrackID", "\(track.trackID)")
        builder.addFormatted("MediaType", "\(typeName) (\(mediaType.rawValue))")

        if let enabled = try? await track.load(.isEnabled) {
            builder.addFormatted("IsEnabled", enabled ? "Yes" : "No")
        }
        if let languageTag = try? await track.load(.extendedLanguageTag), !languageTag.isEmpty {
            builder.addFormatted("ExtendedLanguageTag", languageTag)
        }

        if mediaType == .video {
            await addVideoTrackDetails(track: track, builder: &builder)
        } else if mediaType == .audio {
            await addAudioTrackDetails(track: track, builder: &builder)
        }

        return builder.group.items.isEmpty ? nil : builder.group
    }

    /// Video specific details: codec, dimensions, frame rate, rotation, color.
    private static func addVideoTrackDetails(track: AVAssetTrack, builder: inout GroupBuilder) async {
        if let naturalSize = try? await track.load(.naturalSize), naturalSize.width > 0 {
            builder.addFormatted("NaturalSize", "\(Int(naturalSize.width)) x \(Int(naturalSize.height))")
        }
        if let frameRate = try? await track.load(.nominalFrameRate), frameRate > 0 {
            builder.addFormatted("NominalFrameRate", String(format: "%.2f fps", frameRate))
        }
        if let dataRate = try? await track.load(.estimatedDataRate), dataRate > 0 {
            builder.addFormatted("EstimatedDataRate", ValueFormatter.bitRateString(bitsPerSecond: Double(dataRate)))
        }
        if let transform = try? await track.load(.preferredTransform) {
            let degrees = (atan2(transform.b, transform.a) * 180.0 / .pi).rounded()
            let normalized = Int(degrees) % 360
            if normalized != 0 {
                builder.addFormatted("Rotation", "\(normalized)°")
            }
        }

        // Codec details from the first format description (typed
        // [CMFormatDescription] thanks to the async loading API).
        let formatDescriptions = (try? await track.load(.formatDescriptions)) ?? []
        guard let formatDescription = formatDescriptions.first else { return }
        let subType = CMFormatDescriptionGetMediaSubType(formatDescription)
        let codec = fourCCString(subType)
        if let longName = codecNames[codec] {
            builder.addFormatted("Codec", "\(longName) (\(codec))")
        } else {
            builder.addFormatted("Codec", codec)
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        if dimensions.width > 0 {
            builder.addFormatted("Dimensions", "\(dimensions.width) x \(dimensions.height)")
        }

        // Color information (HDR videos carry primaries/transfer here).
        if let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] {
            if let primaries = extensions[kCMFormatDescriptionExtension_ColorPrimaries as String] {
                builder.addFormatted("ColorPrimaries", ValueFormatter.describe(primaries))
            }
            if let transfer = extensions[kCMFormatDescriptionExtension_TransferFunction as String] {
                builder.addFormatted("TransferFunction", ValueFormatter.describe(transfer))
            }
            if let matrix = extensions[kCMFormatDescriptionExtension_YCbCrMatrix as String] {
                builder.addFormatted("YCbCrMatrix", ValueFormatter.describe(matrix))
            }
        }
    }

    /// Audio specific details: codec, sample rate, channel layout, bit depth.
    private static func addAudioTrackDetails(track: AVAssetTrack, builder: inout GroupBuilder) async {
        let formatDescriptions = (try? await track.load(.formatDescriptions)) ?? []
        if let formatDescription = formatDescriptions.first {
            let subType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let codec = fourCCString(subType)
            if let longName = codecNames[codec] {
                builder.addFormatted("Codec", "\(longName) (\(codec))")
            } else {
                builder.addFormatted("Codec", codec)
            }

            if let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                let asbd = streamDescription.pointee
                if asbd.mSampleRate > 0 {
                    builder.addFormatted("SampleRate", "\(ValueFormatter.trimmed(asbd.mSampleRate)) Hz")
                }
                if asbd.mChannelsPerFrame > 0 {
                    builder.addFormatted("Channels", "\(asbd.mChannelsPerFrame)")
                }
                if asbd.mBitsPerChannel > 0 {
                    builder.addFormatted("BitsPerChannel", "\(asbd.mBitsPerChannel)")
                }
            }
        }
        if let dataRate = try? await track.load(.estimatedDataRate), dataRate > 0 {
            builder.addFormatted("EstimatedDataRate", ValueFormatter.bitRateString(bitsPerSecond: Double(dataRate)))
        }
    }

    // MARK: - Embedded metadata (QuickTime keys, iTunes, ID3, ...)

    /// Builds one group per metadata format present in the container.
    private static func metadataGroups(asset: AVAsset) async -> [MetadataGroup] {
        let formats = (try? await asset.load(.availableMetadataFormats)) ?? []
        var groups: [MetadataGroup] = []

        for format in formats {
            let items = (try? await asset.loadMetadata(for: format)) ?? []
            guard !items.isEmpty else { continue }

            var builder = GroupBuilder(name: displayName(forMetadataFormat: format))
            for item in items {
                guard let (key, value) = await displayPair(for: item) else { continue }
                builder.add(key, value)
            }
            builder.sortItems()
            if !builder.group.items.isEmpty {
                groups.append(builder.group)
            }
        }
        return groups
    }

    /// Normalizes an `AVMetadataItem` into a display key + raw value pair.
    ///
    /// Key normalization:
    ///   - `com.apple.quicktime.make` -> `Make` (prefix stripped)
    ///   - `com.apple.quicktime.location.accuracy.horizontal`
    ///     -> `LocationAccuracyHorizontal` (dot/dash segments camel-joined,
    ///        matching exiftool's tag names)
    ///   - common keys like `creationDate` -> `CreationDate`
    private static func displayPair(for item: AVMetadataItem) async -> (String, Any)? {
        guard var rawKey = item.key as? String ?? item.commonKey?.rawValue, !rawKey.isEmpty else { return nil }

        rawKey = rawKey.replacingOccurrences(of: "com.apple.quicktime.", with: "")
        rawKey = normalizeKey(rawKey)

        // Prefer the string rendering; fall back to the raw value so numbers
        // still flow through ValueFormatter with the normalized key.
        if let string = try? await item.load(.stringValue), !string.isEmpty {
            return (rawKey, string)
        }
        guard let value = try? await item.load(.value) else { return nil }

        if let data = value as? Data {
            // Some Apple keys store binary property lists; decode when possible.
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
                return (rawKey, plist)
            }
            return (rawKey, "<binary data, \(data.count) bytes>")
        }
        return (rawKey, value)
    }

    /// Maps `AVMetadataFormat` identifiers to friendly group names.
    private static func displayName(forMetadataFormat format: AVMetadataFormat) -> String {
        switch format.rawValue {
        case AVMetadataFormat.quickTimeMetadata.rawValue:  return "QuickTime Metadata"
        case AVMetadataFormat.quickTimeUserData.rawValue:  return "QuickTime User Data"
        case AVMetadataFormat.iTunesMetadata.rawValue:     return "iTunes Metadata"
        case AVMetadataFormat.id3Metadata.rawValue:        return "ID3 Metadata"
        case AVMetadataFormat.isoUserData.rawValue:        return "ISO User Data"
        case AVMetadataFormat.hlsMetadata.rawValue:        return "HLS Metadata"
        default:                                            return format.rawValue
        }
    }

    // MARK: - Helpers

    /// Friendly track type labels for the group header.
    private static func mediaTypeDisplayName(_ mediaType: AVMediaType) -> String {
        switch mediaType {
        case .video:         return "Video"
        case .audio:         return "Audio"
        case .text:          return "Text"
        case .closedCaption: return "Closed Caption"
        case .subtitle:      return "Subtitle"
        case .metadata:      return "Metadata"
        case .timecode:      return "Timecode"
        case .depthData:     return "Depth Data"
        default:
            // AVMediaType has no case for "auxv" (auxiliary video, e.g. the
            // HDR gain map track in iPhone videos); label it by raw value.
            if mediaType.rawValue == "auxv" { return "Auxiliary Video" }
            return mediaType.rawValue.capitalized
        }
    }

    /// Normalizes container metadata keys:
    ///   - dot/dash separated segments are camel-joined
    ///     (`location.accuracy.horizontal` -> `LocationAccuracyHorizontal`);
    ///   - leading lowercase is capitalized (`creationDate` -> `CreationDate`).
    private static func normalizeKey(_ key: String) -> String {
        guard key.contains(".") || key.contains("-") else {
            guard let first = key.first, first.isLowercase else { return key }
            return first.uppercased() + key.dropFirst()
        }
        return key
            .split(whereSeparator: { $0 == "." || $0 == "-" })
            .map { segment in
                guard let first = segment.first, first.isLowercase else { return String(segment) }
                return first.uppercased() + segment.dropFirst()
            }
            .joined()
    }

    /// Renders a FourCC (`0x68766331`) as a printable string (`hvc1`).
    /// Non-printable bytes are shown as `·`.
    static func fourCCString(_ code: FourCharCode) -> String {
        var result = ""
        result.reserveCapacity(4)
        for shift in stride(from: 24, through: 0, by: -8) {
            let byte = UInt8(truncatingIfNeeded: code >> UInt32(shift))
            result.append((0x20...0x7E).contains(byte) ? String(UnicodeScalar(byte)) : "·")
        }
        return result
    }

    /// Well-known codec FourCCs to long names. Unknown codecs are displayed
    /// with their raw FourCC only (leave it as-is).
    static let codecNames: [String: String] = [
        // Video
        "hvc1": "HEVC (H.265)",
        "hev1": "HEVC (H.265)",
        "avc1": "H.264 / AVC",
        "avc3": "H.264 / AVC",
        "apcn": "Apple ProRes 422",
        "apch": "Apple ProRes 422 HQ",
        "apcs": "Apple ProRes 422 LT",
        "apco": "Apple ProRes 422 Proxy",
        "ap4h": "Apple ProRes 4444",
        "ap4x": "Apple ProRes 4444 XQ",
        "mp4v": "MPEG-4 Visual",
        "jpeg": "Photo-JPEG",
        "vp09": "VP9",
        "av01": "AV1",
        "dvh1": "Dolby Vision HEVC",
        "dvhe": "Dolby Vision HEVC",
        // Audio
        "mp4a": "AAC",
        "lpcm": "Linear PCM",
        "sowt": "Linear PCM (little-endian)",
        "twos": "Linear PCM (big-endian)",
        "alac": "Apple Lossless",
        ".mp3": "MP3",
        "mp3 ": "MP3",
        "ac-3": "Dolby Digital (AC-3)",
        "ec-3": "Dolby Digital Plus (E-AC-3)",
        "opus": "Opus",
        "flac": "FLAC",
        "samr": "AMR Narrowband",
        "ulaw": "μ-law",
        "alaw": "A-law",
        // Timed / other
        "mebx": "Timed Metadata",
        "text": "Text",
        "tx3g": "3GPP Timed Text"
    ]
}
