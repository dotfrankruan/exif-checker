import SwiftUI

/// Root view: shows the drop zone until a file is loaded, then the metadata
/// browser. Handles drag & drop, the search field, the toolbar, error
/// alerts, and files opened from Finder (Open With / dock drops).
struct ContentView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        Group {
            if let document = model.document {
                MetadataBrowserView(document: document, model: model)
            } else {
                DropZoneView(model: model)
            }
        }
        .frame(minWidth: 860, minHeight: 540)
        .navigationTitle(model.document?.fileURL.lastPathComponent ?? "ExifChecker")
        // Drag & drop anywhere in the window.
        .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { providers in
            model.handleDrop(providers)
        }
        // Files opened via Finder / Dock / `open -a`.
        .onOpenURL { url in
            model.load(url)
        }
        // Toolbar filter field (only useful with a document, but keeping it
        // always mounted avoids toolbar churn when switching files).
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Filter fields")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.document != nil {
                    Menu {
                        Button("Export JSON…") { model.exportJSON() }
                        Button("Copy All Fields") { model.copyAll() }
                        Divider()
                        Button("Close File") { model.closeDocument() }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                    }
                }
                Button { model.openPanel() } label: {
                    Label("Open…", systemImage: "folder")
                }
                .help("Open a media file (⌘O)")
            }
        }
        // Loading overlay.
        .overlay {
            if model.isLoading {
                ProgressView("Reading metadata…")
                    .controlSize(.large)
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        // Extraction errors (e.g. file not found).
        .alert(
            "Cannot Open File",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
