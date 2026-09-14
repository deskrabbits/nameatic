import Foundation
import CoreGraphics
import Observation

@MainActor
@Observable
final class BatchFile: Identifiable {
    let id = UUID()
    var url: URL
    let originalName: String
    var draftName: String
    var isRenamed = false
    var duration: TimeInterval?
    var thumbnail: CGImage?

    init(url: URL) {
        self.url = url
        self.originalName = url.lastPathComponent
        self.draftName = url.lastPathComponent
    }

    /// Sidebar label: the new name once confirmed, the original until then.
    var displayName: String {
        isRenamed ? url.lastPathComponent : originalName
    }

    var durationLabel: String {
        guard let duration, duration.isFinite else { return "–:––" }
        let secs = Int(duration.rounded())
        return "\(secs / 60):" + String(format: "%02d", secs % 60)
    }
}
