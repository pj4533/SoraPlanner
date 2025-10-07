//
//  VideoGenerationViewModel.swift
//  SoraPlanner
//
//  ViewModel for managing video generation state and business logic
//

import Foundation
import AVKit
import Combine
import os

@MainActor
class VideoGenerationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var prompt: String = ""
    @Published var duration: Int = 4 // Duration in seconds (default 4)
    @Published var currentVideoJob: VideoJob?
    @Published var videoURL: URL?
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private var apiService: VideoAPIService?
    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?

    // MARK: - Computed Properties
    var statusMessage: String {
        guard let job = currentVideoJob else {
            return "Ready to generate"
        }

        switch job.status {
        case .queued:
            return "Queued for generation..."
        case .processing:
            if let progress = job.progress {
                return "Processing: \(progress)%"
            }
            return "Processing..."
        case .completed:
            return "Generation complete!"
        case .failed:
            return "Generation failed"
        }
    }

    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Initialization
    init() {
        SoraPlannerLoggers.ui.info("VideoGenerationViewModel initialized")
        do {
            self.apiService = try VideoAPIService()
        } catch {
            SoraPlannerLoggers.ui.error("Failed to initialize API service: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Public Methods

    /// Start video generation process
    func generateVideo() async {
        guard canGenerate else {
            SoraPlannerLoggers.ui.warning("Cannot generate: invalid state")
            return
        }

        SoraPlannerLoggers.ui.info("Starting video generation")

        isGenerating = true
        errorMessage = nil
        videoURL = nil
        currentVideoJob = nil

        do {
            guard let service = apiService else {
                throw VideoAPIError.missingAPIKey
            }

            // Create video job
            let job = try await service.createVideo(prompt: prompt, seconds: String(duration))
            currentVideoJob = job

            SoraPlannerLoggers.ui.info("Video job created: \(job.id)")

            // Start polling for status updates
            startPolling()

        } catch {
            SoraPlannerLoggers.ui.error("Failed to create video job: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }

    /// Cancel ongoing generation
    func cancelGeneration() {
        SoraPlannerLoggers.ui.info("Cancelling video generation")
        stopPolling()
        isGenerating = false
        currentVideoJob = nil
        errorMessage = nil
    }

    // MARK: - Private Methods

    /// Start polling for video status updates
    private func startPolling() {
        guard let videoId = currentVideoJob?.id else {
            SoraPlannerLoggers.ui.error("Cannot poll: no video ID")
            return
        }

        SoraPlannerLoggers.ui.info("Starting status polling for video: \(videoId)")

        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    guard let service = apiService else {
                        throw VideoAPIError.missingAPIKey
                    }

                    // Poll for status
                    let updatedJob = try await service.getVideoStatus(videoId: videoId)
                    currentVideoJob = updatedJob

                    // Handle status changes
                    switch updatedJob.status {
                    case .completed:
                        SoraPlannerLoggers.ui.info("Video generation completed")
                        await handleVideoCompleted(videoId: videoId)
                        return

                    case .failed:
                        SoraPlannerLoggers.ui.error("Video generation failed: \(updatedJob.error?.message ?? "Unknown error")")
                        errorMessage = updatedJob.error?.message ?? "Video generation failed"
                        isGenerating = false
                        return

                    case .queued, .processing:
                        // Continue polling
                        SoraPlannerLoggers.ui.debug("Video status: \(updatedJob.status.rawValue)")
                    }

                    // Wait 2 seconds before next poll
                    try await Task.sleep(nanoseconds: 2_000_000_000)

                } catch is CancellationError {
                    SoraPlannerLoggers.ui.info("Polling cancelled")
                    return
                } catch {
                    SoraPlannerLoggers.ui.error("Polling error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    isGenerating = false
                    return
                }
            }
        }
    }

    /// Stop polling for status updates
    nonisolated private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        SoraPlannerLoggers.ui.info("Status polling stopped")
    }

    /// Handle video completion - download and prepare for playback
    private func handleVideoCompleted(videoId: String) async {
        do {
            guard let service = apiService else {
                throw VideoAPIError.missingAPIKey
            }

            SoraPlannerLoggers.video.info("Downloading completed video: \(videoId)")
            let localURL = try await service.downloadVideo(videoId: videoId)
            videoURL = localURL
            isGenerating = false

            SoraPlannerLoggers.video.info("Video ready for playback: \(localURL.path)")

        } catch {
            SoraPlannerLoggers.video.error("Failed to download video: \(error.localizedDescription)")
            errorMessage = "Failed to download video: \(error.localizedDescription)"
            isGenerating = false
        }
    }

    // MARK: - Cleanup
    deinit {
        stopPolling()
        SoraPlannerLoggers.ui.info("VideoGenerationViewModel deinitialized")
    }
}
