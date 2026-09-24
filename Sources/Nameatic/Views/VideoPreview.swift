import SwiftUI
import AVFoundation
import AppKit

/// Owns the AVPlayer for the rename screen; loops the current clip with sound.
@MainActor
@Observable
final class PlayerController {
    let player = AVQueuePlayer()
    private(set) var isPlaying = false
    private var currentURL: URL?
    private var looper: AVPlayerLooper?
    private var statusObservation: NSKeyValueObservation?

    init() {
        player.isMuted = false
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { player, _ in
            let playing = player.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.isPlaying = playing
            }
        }
    }

    /// - Parameter volume: playback volume leveled to match the batch's
    ///   reference clip (see `BatchStore`'s audio analysis).
    func show(url: URL?, volume: Float) {
        player.volume = volume
        guard url != currentURL else { return }
        currentURL = url
        looper = nil
        player.removeAllItems()
        if let url {
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            player.play()
        }
    }

    /// Applies an updated volume without reloading the current clip — used
    /// when its analyzed level arrives after playback already started.
    func setVolume(_ volume: Float) {
        player.volume = volume
    }

    func togglePlayback() {
        if isPlaying { player.pause() } else { player.play() }
    }

    /// Tear down playback entirely (leaving the rename screen) so no audio
    /// keeps running and the file handles are released.
    func stop() {
        looper = nil
        player.pause()
        player.removeAllItems()
        currentURL = nil
    }
}

/// Chromeless AVPlayerLayer view (the design shows bare video, no controls).
struct PlayerLayerView: NSViewRepresentable {
    var player: AVPlayer

    func makeNSView(context: Context) -> LayerHostView {
        let view = LayerHostView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ view: LayerHostView, context: Context) {
        view.playerLayer.player = player
    }

    final class LayerHostView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
