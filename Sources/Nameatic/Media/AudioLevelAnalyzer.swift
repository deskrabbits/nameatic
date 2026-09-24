import AVFoundation
import CoreMedia

/// Estimates a clip's overall loudness so batch playback can be leveled to
/// roughly match, without ever touching the file on disk.
@MainActor
enum AudioLevelAnalyzer {
    /// Average RMS level of the clip's audio, in dBFS (0 = full scale, more
    /// negative = quieter). Returns nil if there's no audio track or it
    /// can't be read.
    nonisolated static func analyzeAverageLevel(url: URL) async -> Float? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset)
        else { return nil }

        // A clip's first stretch is representative enough of its overall
        // loudness — no need to decode an hour-long file to level it.
        if let duration = try? await asset.load(.duration), duration.isNumeric {
            let cap = CMTime(seconds: 45, preferredTimescale: 600)
            reader.timeRange = CMTimeRange(start: .zero, duration: min(duration, cap))
        }

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 22050,
        ])
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }

        var sumOfSquares: Double = 0
        var sampleCount = 0

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let blockBuffer = sampleBuffer.dataBuffer else { continue }
            let length = blockBuffer.dataLength
            let frameCount = length / MemoryLayout<Float>.size
            guard frameCount > 0 else { continue }
            var samples = [Float](repeating: 0, count: frameCount)
            let status = samples.withUnsafeMutableBytes { raw in
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            guard status == noErr else { continue }
            for sample in samples {
                sumOfSquares += Double(sample) * Double(sample)
            }
            sampleCount += frameCount
        }

        guard sampleCount > 0 else { return nil }
        let rms = sqrt(sumOfSquares / Double(sampleCount))
        guard rms > 0 else { return -80 }
        return Float(20 * log10(rms))
    }
}
