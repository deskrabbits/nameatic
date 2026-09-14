import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BuilderScreen: View {
    @Environment(BatchStore.self) private var store
    @State private var importerPresented = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            WindowHeader(title: "New Batch") {
                EmptyView()
            } trailing: {
                Button("+") { importerPresented = true }
                    .buttonStyle(GlassButtonStyle(width: 30))
                    .font(.system(size: 15, weight: .semibold))
                    .help("Add files")
                    .accessibilityLabel("Add files")
                Button("–") { store.removeLast() }
                    .buttonStyle(GlassButtonStyle(width: 30))
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(store.files.isEmpty)
                    .help("Remove last file")
                    .accessibilityLabel("Remove last file")
                Button("Start Renaming ›") { store.startRenaming() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.files.isEmpty)
                    .accessibilityLabel("Start Renaming")
            }

            if store.files.isEmpty {
                emptyState
            } else {
                fileList
            }

            Divider()
            HStack {
                Text(store.fileCountLabel)
                Spacer()
                Text("Drag video files anywhere in this window, or use + / –")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $importerPresented,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                store.add(urls: urls)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let videos = urls.filter { BatchStore.isVideo($0) }
            guard !videos.isEmpty else { return false }
            store.add(urls: videos)
            return true
        } isTargeted: {
            isDropTargeted = $0
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.files) { file in
                    FileRow(file: file) { store.remove(file) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                style: StrokeStyle(lineWidth: 2, dash: [7, 6])
            )
            .overlay {
                VStack(spacing: 8) {
                    Text("Drop videos here")
                        .font(.system(size: 15, weight: .semibold))
                    Text("or click + to choose files")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FileRow: View {
    var file: BatchFile
    var onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailView(image: file.thumbnail, width: 44, height: 28, cornerRadius: 6)
            Text(file.url.lastPathComponent)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(file.durationLabel)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(RemoveButtonStyle())
            .opacity(hovering ? 1 : 0.45)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            hovering ? Color.primary.opacity(0.035) : .clear,
            in: RoundedRectangle(cornerRadius: 9)
        )
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
        }
    }
}

private struct RemoveButtonStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(hovering ? Color.red : Color.primary.opacity(0.32))
            .frame(width: 22, height: 22)
            .background(
                hovering ? Color.red.opacity(0.14) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
