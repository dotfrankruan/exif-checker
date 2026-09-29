import AppKit
import ExifCheckerCore
import SwiftUI

/// The metadata browser: header + searchable, grouped field list + status bar.
struct MetadataBrowserView: View {
    let document: MetadataDocument
    @ObservedObject var model: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            FileHeaderView(document: document, thumbnail: model.thumbnail)
            Divider()

            List {
                ForEach(model.filteredGroups) { group in
                    Section {
                        ForEach(group.items) { item in
                            MetadataRowView(item: item, language: model.noteLanguage)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Text(group.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(group.items.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Divider()
            statusBar
        }
    }

    /// Bottom status bar with totals and the full file path.
    private var statusBar: some View {
        HStack {
            let filteredCount = model.filteredGroups.reduce(0) { $0 + $1.items.count }
            if model.searchText.isEmpty {
                Text("\(document.itemCount) fields in \(document.groups.count) groups")
            } else {
                Text("\(filteredCount) of \(document.itemCount) fields match")
            }
            Spacer()
            Text(document.fileURL.path)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

/// One metadata field: display name + raw key on the left, the formatted
/// value in the middle (selectable), and the localized annotation on the
/// right when the field is well-known.
struct MetadataRowView: View {
    let item: MetadataItem
    let language: NoteLanguage

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            // Left: humanized name + raw container key.
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout.weight(.medium))
                Text(item.key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 220, alignment: .leading)

            // Middle: the formatted value, selectable/copyable.
            Text(item.value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Right: annotation for common fields; intentionally empty for
            // unknown ones (leave it as-is).
            Text(item.note?.text(for: language) ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 220, alignment: .leading)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Copy Value") { copyToPasteboard(item.value) }
            Button("Copy Key and Value") { copyToPasteboard("\(item.key): \(item.value)") }
        }
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
