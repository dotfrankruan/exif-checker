import ExifCheckerCore
import SwiftUI

/// Header above the metadata list: thumbnail, file name, path, and a row of
/// summary chips (type, size, dimensions, duration, field count).
struct FileHeaderView: View {
    let document: MetadataDocument
    let thumbnail: NSImage?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            thumbnailView

            VStack(alignment: .leading, spacing: 5) {
                Text(document.fileURL.lastPathComponent)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(document.fileURL.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    if let type = document.contentType?.localizedDescription {
                        Chip(text: type)
                    }
                    Chip(text: ByteCountFormatter.string(fromByteCount: document.fileSize, countStyle: .file))
                    if let dimensions = dimensionsText {
                        Chip(text: dimensions)
                    }
                    if let duration = document.firstValue(forKeys: ["Duration"]) {
                        Chip(text: duration)
                    }
                    Chip(text: "\(document.itemCount) fields")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Subviews

    @ViewBuilder
    private var thumbnailView: some View {
        let image = thumbnail.flatMap { Image(nsImage: $0) }
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary.opacity(0.5))
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }

    // MARK: Derived values

    /// Combined "width × height" from whichever extractor provided them.
    private var dimensionsText: String? {
        if let width = document.firstValue(forKeys: ["PixelWidth"]),
           let height = document.firstValue(forKeys: ["PixelHeight"]) {
            return "\(width) × \(height)"
        }
        // Videos carry dimensions per track ("1920 x 1440").
        return document.firstValue(forKeys: ["Dimensions"])
    }
}

/// A small rounded label used for the summary chips in the header.
struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.6), in: Capsule())
    }
}
