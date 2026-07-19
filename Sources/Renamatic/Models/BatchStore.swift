import Foundation
import UniformTypeIdentifiers

enum Step {
    case builder
    case rename
}

@MainActor
@Observable
final class BatchStore {
    static let shared = BatchStore()

    var files: [BatchFile] = []
    var step: Step = .builder
    var selectedIndex = 0
    var renameError: RenameError?
    /// Bumped whenever the rename field should grab focus and select all.
    var focusRequest = 0

    struct RenameError: Identifiable {
        let id = UUID()
        let message: String
    }

    var currentFile: BatchFile? {
        files.indices.contains(selectedIndex) ? files[selectedIndex] : nil
    }

    var renamedCount: Int { files.count(where: \.isRenamed) }
    var allDone: Bool { !files.isEmpty && renamedCount == files.count }
    var fileCountLabel: String { "\(files.count) \(files.count == 1 ? "file" : "files")" }
    var renamedSummary: String { "\(renamedCount) renamed · \(files.count - renamedCount) remaining" }
    var indexLabel: String { "\(selectedIndex + 1) of \(files.count)" }

    // MARK: - Batch building

    static func isVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    func add(urls: [URL]) {
        let existing = Set(files.map { $0.url.standardizedFileURL.path })
        for url in urls where Self.isVideo(url) && !existing.contains(url.standardizedFileURL.path) {
            let file = BatchFile(url: url)
            files.append(file)
            Task { await MediaLoader.load(into: file) }
        }
    }

    func remove(_ file: BatchFile) {
        files.removeAll { $0.id == file.id }
        clampSelection()
    }

    func removeLast() {
        guard !files.isEmpty else { return }
        files.removeLast()
        clampSelection()
    }

    private func clampSelection() {
        selectedIndex = max(0, min(selectedIndex, files.count - 1))
    }

    // MARK: - Rename flow

    func startRenaming() {
        guard !files.isEmpty else { return }
        selectedIndex = 0
        step = .rename
        focusRequest += 1
    }

    func backToBuilder() {
        step = .builder
    }

    /// "Done" — the batch is complete; reset for the next one.
    func finishBatch() {
        files = []
        selectedIndex = 0
        step = .builder
    }

    func select(_ index: Int) {
        guard files.indices.contains(index) else { return }
        selectedIndex = index
        focusRequest += 1
    }

    func moveSelection(by delta: Int) {
        select(max(0, min(files.count - 1, selectedIndex + delta)))
    }

    /// ⌘⌫ — move the current file to the Trash and drop it from the batch.
    func trashCurrentFile() {
        guard let file = currentFile else { return }
        do {
            try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
        } catch {
            renameError = RenameError(message: "Couldn't move “\(file.url.lastPathComponent)” to the Trash: \(error.localizedDescription)")
            return
        }
        files.removeAll { $0.id == file.id }
        if files.isEmpty {
            finishBatch()
        } else {
            clampSelection()
            focusRequest += 1
        }
    }

    /// ⏎ — rename the current file on disk, mark it done, advance.
    func confirmRename() {
        guard let file = currentFile else { return }

        var name = file.draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != "." , name != ".." else {
            renameError = RenameError(message: "Enter a file name.")
            return
        }
        guard !name.contains("/"), !name.contains(":") else {
            renameError = RenameError(message: "File names can't contain “/” or “:”.")
            return
        }
        // Typing just "family_trip_01" shouldn't strip the extension.
        let originalExt = file.url.pathExtension
        if !originalExt.isEmpty && (name as NSString).pathExtension.isEmpty {
            name += ".\(originalExt)"
        }

        let dest = file.url.deletingLastPathComponent().appendingPathComponent(name)
        if dest.standardizedFileURL.path != file.url.standardizedFileURL.path {
            if FileManager.default.fileExists(atPath: dest.path) {
                renameError = RenameError(message: "A file named “\(name)” already exists in this folder.")
                return
            }
            do {
                try FileManager.default.moveItem(at: file.url, to: dest)
            } catch {
                renameError = RenameError(message: "Couldn't rename “\(file.url.lastPathComponent)”: \(error.localizedDescription)")
                return
            }
            file.url = dest
        }

        file.draftName = name
        file.isRenamed = true
        moveSelection(by: 1)
    }
}
