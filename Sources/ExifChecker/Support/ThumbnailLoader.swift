// `@preconcurrency` silences Sendable warnings for the AVFoundation types
// used here; each thumbnail is produced sequentially and handed back as an
// NSImage, so nothing unsafe crosses isolation boundaries.
@preconcurrency import AVFoundation
import AppKit
import ExifCheckerCore
import ImageIO

/// Produces preview thumbnails for the header area:
///   - images: downscaled via ImageIO (fast, memory friendly);
///   - videos: first frame via `AVAssetImageGenerator`;
///   - audio:  embedded artwork when present;
///   - fallback: the Finder icon of the file.
enum ThumbnailLoader {

    /// Maximum pixel size (longest edge) of generated thumbnails.
    private static let maxPixelSize = 192

    static func thumbnail(for url: URL, kind: MediaKind) async -> NSImage? {
        switch kind {
        case .image:
            return imageThumbnail(url: url)
        case .video:
            return await videoThumbnail(url: url) ?? workspaceIcon(url: url)
        case .audio:
            return await audioArtwork(url: url) ?? workspaceIcon(url: url)
        case .other:
            return workspaceIcon(url: url)
        }
    }

    /// Downscales a still image using ImageIO's thumbnail support.
    static func imageThumbnail(url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Grabs a frame near the start of a video.
    static func videoThumbnail(url: URL) async -> NSImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixelSize * 2, height: maxPixelSize * 2)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let (cgImage, _) = try? await generator.image(at: time) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Extracts embedded cover art from audio files (ID3 APIC / iTunes covr).
    static func audioArtwork(url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
        for item in metadata where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue) {
                return NSImage(data: data)
            }
        }
        return nil
    }

    /// The file's Finder icon as a last resort.
    static func workspaceIcon(url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}
