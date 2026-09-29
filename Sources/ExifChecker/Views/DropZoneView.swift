import SwiftUI

/// Empty state: a large dashed drop target with an open button.
struct DropZoneView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [9, 7])
                    )
                    .foregroundStyle(
                        model.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35)
                    )
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(model.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                    }
                    .animation(.easeInOut(duration: 0.15), value: model.isDropTargeted)

                VStack(spacing: 14) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(model.isDropTargeted ? Color.accentColor : Color.secondary)
                    Text("Drop a media file here")
                        .font(.title2.weight(.medium))
                    Text("Images · Videos · Audio")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open File…") { model.openPanel() }
                        .controlSize(.large)
                        .padding(.top, 6)
                }
                .padding(48)
            }
            .frame(maxWidth: 560, maxHeight: 380)
            Spacer()
        }
        .padding(32)
    }
}
