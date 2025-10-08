//
//  LoopingVideoPlayerView.swift
//  SoraPlanner
//
//  Custom video player with seamless looping using AVPlayerLooper
//

import SwiftUI
import AVKit
import AVFoundation
import os

/// A custom video player view that provides seamless, gapless looping playback
/// using AVPlayerLooper and AVQueuePlayer for optimal user experience.
struct LoopingVideoPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let view = PlayerView()
        context.coordinator.setupPlayer(with: url, in: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No-op: URL doesn't change after initialization
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator {
        private var player: AVQueuePlayer?
        private var playerLooper: AVPlayerLooper?
        private var playerLayer: AVPlayerLayer?

        func setupPlayer(with url: URL, in view: NSView) {
            SoraPlannerLoggers.video.info("Setting up looping video player for URL: \(url.lastPathComponent)")

            // Create player item from URL
            let playerItem = AVPlayerItem(url: url)

            // Create queue player (required for AVPlayerLooper)
            let queuePlayer = AVQueuePlayer(playerItem: playerItem)
            self.player = queuePlayer

            // Create player looper for seamless, gapless playback
            // This automatically queues the next iteration before the current one ends
            let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
            self.playerLooper = looper

            // Create and configure player layer
            let playerLayer = AVPlayerLayer(player: queuePlayer)
            playerLayer.videoGravity = .resizeAspect
            playerLayer.frame = view.bounds
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            self.playerLayer = playerLayer

            // Add player layer to view
            view.layer = CALayer()
            view.wantsLayer = true
            view.layer?.addSublayer(playerLayer)

            // Start playback automatically
            queuePlayer.play()
            SoraPlannerLoggers.video.info("Looping video player started")
        }

        deinit {
            SoraPlannerLoggers.video.info("Cleaning up looping video player")
            player?.pause()
            playerLooper?.disableLooping()
            playerLooper = nil
            player = nil
            playerLayer = nil
        }
    }

    // MARK: - Custom NSView

    /// Custom NSView container for the AVPlayerLayer
    private class PlayerView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.wantsLayer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
