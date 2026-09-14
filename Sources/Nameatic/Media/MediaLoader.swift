import AVFoundation
import CoreGraphics

@MainActor
enum MediaLoader {
    static func load(into file: BatchFile) async {
        let url = file.url
        async let duration = loadDuration(url: url)
        async let thumbnail = loadThumbnail(url: url)
        file.duration = await duration
        file.thumbnail = await thumbnail
    }

    private nonisolated static func loadDuration(url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        return duration.seconds
    }

    private nonisolated static func loadThumbnail(url: URL) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 320)
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        return try? await generator.image(at: time).image
    }
}
