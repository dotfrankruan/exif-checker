import AppKit
import ExifCheckerCore
import SwiftUI
import UniformTypeIdentifiers

/// Central view model: owns the currently inspected document, loading state,
/// the search query, and all user actions (open, drop, export, copy).
@MainActor
final class AppViewModel: ObservableObject {

    // MARK: Published state

    /// The currently inspected file's metadata, `nil` shows the drop zone.
    @Published var document: MetadataDocument?

    /// Preview thumbnail for the header (image, video poster frame, or icon).
    @Published var thumbnail: NSImage?

    /// True while extraction is running.
    @Published var isLoading = false

    /// Set when loading fails; drives the alert in the UI.
    @Published var errorMessage: String?

    /// Live search query filtering the metadata list.
    @Published var searchText = ""

    /// True while a drag hovers over the window (drop zone highlighting).
    @Published var isDropTargeted = false

    /// Language of the field annotations. English by default; switchable to
    /// Chinese at runtime without re-reading the file.
    @Published var noteLanguage: NoteLanguage = .english

    // MARK: Loading

    /// Monotonic token identifying the most recent load request. Extraction
    /// is async, so a slow load can finish *after* a newer one was started;
    /// stale completions are discarded instead of clobbering newer state.
    private var loadGeneration = 0

    /// Loads (or reloads) a file. Safe to call from any context; extraction
    /// itself runs off the main actor inside the core library.
    func load(_ url: URL) {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let document = try await MetadataLoader.load(from: url)
                guard generation == self.loadGeneration else { return }
                self.document = document
                let thumbnail = await ThumbnailLoader.thumbnail(for: url, kind: document.kind)
                guard generation == self.loadGeneration else { return }
                self.thumbnail = thumbnail
            } catch {
                guard generation == self.loadGeneration else { return }
                self.document = nil
                self.thumbnail = nil
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    // MARK: User actions

    /// Presents the system open panel and loads the selected file.
    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item] // any file — the extractors decide
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image, video, or audio file"
        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
    }

    /// Handles files dropped onto the window. Accepts the first file URL.
    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let directURL = item as? URL {
                url = directURL
            }
            guard let url else { return }
            Task { @MainActor in self.load(url) }
        }
        return true
    }

    /// Copies the whole document as an exiftool-style text report.
    func copyAll() {
        guard let document else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(document.plainTextReport(), forType: .string)
    }

    /// Exports the whole document as pretty-printed JSON via a save panel.
    /// Serialization and write failures are surfaced through `errorMessage`
    /// (the shared error alert) instead of being silently swallowed.
    func exportJSON() {
        guard let document else { return }
        let data: Data
        do {
            data = try document.jsonReport()
        } catch {
            errorMessage = "Could not serialize the metadata as JSON: \(error.localizedDescription)"
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue =
            document.fileURL.deletingPathExtension().lastPathComponent + "-metadata.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Could not write to \(url.path): \(error.localizedDescription)"
        }
    }

    /// Closes the current document and returns to the drop zone.
    /// Also invalidates any in-flight load, so a slow extraction finishing
    /// afterwards cannot resurrect the closed document.
    func closeDocument() {
        loadGeneration += 1
        isLoading = false
        document = nil
        thumbnail = nil
        searchText = ""
    }

    // MARK: Derived state

    /// The document's groups filtered by the current search query.
    /// Matches against raw keys, display names, values, and annotations.
    var filteredGroups: [MetadataGroup] {
        guard let document else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return document.groups }
        return document.groups.compactMap { group in
            let matches = group.items.filter { item in
                item.key.localizedCaseInsensitiveContains(query)
                    || item.name.localizedCaseInsensitiveContains(query)
                    || item.value.localizedCaseInsensitiveContains(query)
                    || (item.note.map {
                        $0.en.localizedCaseInsensitiveContains(query)
                            || $0.zh.localizedCaseInsensitiveContains(query)
                    } ?? false)
            }
            return matches.isEmpty ? nil : MetadataGroup(name: group.name, items: matches)
        }
    }
}
