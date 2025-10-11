//
//  VideoPlayerCoordinator.swift
//  SoraPlanner
//
//  Coordinator for managing shared video playback state
//

import Foundation
import AVKit
import Combine
import os

@MainActor
class VideoPlayerCoordinator: ObservableObject {
    // MARK: - Published Properties
    @Published var currentVideo: VideoJob?
    @Published var videoURL: URL?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let service: VideoAPIService

    // MARK: - Initialization
    init(service: VideoAPIService) {
        self.service = service
        SoraPlannerLoggers.ui.info("VideoPlayerCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Play a video (downloads if needed and presents player)
    func play(_ video: VideoJob) async {
        SoraPlannerLoggers.video.info("Preparing to play video: \(video.id)")

        currentVideo = video
        isLoading = true
        errorMessage = nil
        videoURL = nil

        // Only attempt download for completed videos
        guard video.status == .completed else {
            SoraPlannerLoggers.video.warning("Cannot play video \(video.id) - status is \(video.status.rawValue)")
            errorMessage = "Video is not ready for playback (status: \(video.status.rawValue))"
            isLoading = false
            return
        }

        do {
            // Download video content
            SoraPlannerLoggers.video.info("Downloading video: \(video.id)")
            let localURL = try await service.downloadVideo(videoId: video.id)
            videoURL = localURL

            SoraPlannerLoggers.video.info("Video ready for playback: \(localURL.path)")

        } catch {
            SoraPlannerLoggers.video.error("Failed to download video: \(error.localizedDescription)")
            errorMessage = "Failed to download video: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Dismiss the video player
    func dismiss() {
        SoraPlannerLoggers.video.info("Dismissing video player")
        currentVideo = nil
        videoURL = nil
        errorMessage = nil
        isLoading = false
    }
}
