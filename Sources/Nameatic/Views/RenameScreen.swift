import SwiftUI
import AppKit

struct RenameScreen: View {
    @Environment(BatchStore.self) private var store
    @State private var playerController = PlayerController()
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            WindowHeader(title: "Renaming — \(store.fileCountLabel)") {
                Button("‹ Batch") { store.backToBuilder() }
                    .buttonStyle(GlassButtonStyle())
                    .accessibilityLabel("Back to Batch")
            } trailing: {
                Text(store.renamedSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 6)
                Button("Done") { store.finishBatch() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!store.allDone)
                    .accessibilityLabel("Done")
            }

            HStack(spacing: 0) {
                sidebar
                Divider()
                rightColumn
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            playerController.show(url: store.currentFile?.url)
            installKeyMonitor()
        }
        .onDisappear {
            playerController.stop()
            removeKeyMonitor()
        }
        .onChange(of: store.selectedIndex) {
            playerController.show(url: store.currentFile?.url)
        }
        .onChange(of: store.currentFile?.url) {
            playerController.show(url: store.currentFile?.url)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.files.enumerated()), id: \.element.id) { index, file in
                        SidebarRow(file: file, selected: index == store.selectedIndex) {
                            store.select(index)
                        }
                        .id(file.id)
                    }
                }
                .padding(10)
            }
            .onChange(of: store.selectedIndex) {
                if let file = store.currentFile {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(file.id, anchor: nil)
                    }
                }
            }
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
    }

    // MARK: - Right column

    private var rightColumn: some View {
        VStack(spacing: 0) {
            videoPane
            Divider()
            bottomPane
        }
        .frame(maxWidth: .infinity)
    }

    private var videoPane: some View {
        ZStack {
            Color.black
            PlayerLayerView(player: playerController.player)
            if store.currentFile?.thumbnail == nil && store.currentFile != nil {
                // Brief black flash cover while the first frame decodes.
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            OverlayPill {
                Circle()
                    .fill(playerController.isPlaying ? Color(red: 1, green: 0.27, blue: 0.23) : .secondary)
                    .frame(width: 6, height: 6)
                Text(playerController.isPlaying ? "Playing" : "Paused")
            }
            .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            OverlayPill {
                Text(playerController.player.isMuted ? "Muted" : "Sound On")
            }
            .padding(14)
        }
        .contentShape(Rectangle())
        .onTapGesture { playerController.togglePlayback() }
    }

    private var bottomPane: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text(store.indexLabel)
                    .font(.system(size: 11.5, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.gray.opacity(0.17), in: Capsule())

                renameField

                Text(store.renamedSummary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    KeyCap("↑")
                    KeyCap("↓")
                    Text("Navigate (no save)")
                }
                HStack(spacing: 6) {
                    KeyCap("⏎")
                    Text("Confirm & next")
                }
                HStack(spacing: 6) {
                    KeyCap("⌘⌫")
                    Text("Move to Trash")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 16, trailing: 20))
        .background(.regularMaterial)
    }

    private var renameField: some View {
        RenameField(
            text: Binding(
                get: { store.currentFile?.draftName ?? "" },
                set: { store.currentFile?.draftName = $0 }
            ),
            focusRequest: store.focusRequest,
            onSubmit: { store.confirmRename() },
            onMove: { store.moveSelection(by: $0) }
        )
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(Color.accentColor, lineWidth: 1.5)
        )
        .shadow(color: Color.accentColor.opacity(0.15), radius: 0, x: 0, y: 0)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.15))
                .padding(-3)
        )
    }

    // MARK: - Keyboard

    /// ↑/↓ navigate even when the field isn't focused (e.g. after clicking the video).
    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard store.step == .rename,
                  event.window?.isKeyWindow == true
            else { return event }
            // ⌘⌫ trashes the current file, even while editing the name field.
            if event.keyCode == 51,
               event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
                store.trashCurrentFile()
                return nil
            }
            guard !(event.window?.firstResponder is NSTextView) else { return event }
            switch event.keyCode {
            case 125: store.moveSelection(by: 1); return nil   // ↓
            case 126: store.moveSelection(by: -1); return nil  // ↑
            default: return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

// MARK: - Pieces

private struct SidebarRow: View {
    var file: BatchFile
    var selected: Bool
    var onSelect: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            statusDot
            ThumbnailView(image: file.thumbnail, width: 34, height: 22, cornerRadius: 5)
            Text(file.displayName)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
        }
    }

    private var rowBackground: Color {
        if selected { return Color.accentColor.opacity(0.18) }
        if hovering { return Color.primary.opacity(0.045) }
        return .clear
    }

    @ViewBuilder
    private var statusDot: some View {
        if file.isRenamed {
            Circle()
                .fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                .frame(width: 16, height: 16)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
        } else {
            Circle()
                .strokeBorder(Color.primary.opacity(0.32), lineWidth: 1.5)
                .frame(width: 16, height: 16)
        }
    }
}

private struct OverlayPill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.08).opacity(0.55), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
    }
}

private struct KeyCap: View {
    var label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color.gray.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}
