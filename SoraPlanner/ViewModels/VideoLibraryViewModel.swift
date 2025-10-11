//
//  VideoLibraryViewModel.swift
//  SoraPlanner
//
//  ViewModel for managing video library state
//

import Foundation
import Combine
import os
import Photos

@MainActor
class VideoLibraryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var videos: [VideoJob] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var deletingVideoIds: Set<String> = []
    @Published var savingVideoIds: Set<String> = []

    // MARK: - Private Properties
    private var apiService: VideoAPIService?

    // Polling infrastructure
    private var pollingTasks: [String: Task<Void, Never>] = [:]
    private let pollingInterval: TimeInterval = 5.0
    private let maxConcurrentPolls = 10

    // MARK: - Initialization
    init() {
        SoraPlannerLoggers.ui.info("VideoLibraryViewModel initialized")
        do {
            self.apiService = try VideoAPIService()
        } catch {
            SoraPlannerLoggers.ui.error("Failed to initialize API service: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Public Methods

    /// Retry initializing the API service (e.g., after user adds API key)
    func retryAPIServiceInitialization() {
        guard apiService == nil else {
            // Already initialized
            return
        }

        SoraPlannerLoggers.ui.info("Retrying API service initialization")
        do {
            self.apiService = try VideoAPIService()
            self.errorMessage = nil
            SoraPlannerLoggers.ui.info("API service initialization successful")
        } catch {
            SoraPlannerLoggers.ui.error("Failed to initialize API service: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }

    /// Load all videos from the API
    func loadVideos() async {
        SoraPlannerLoggers.ui.info("Loading video library")

        isLoading = true
        errorMessage = nil

        do {
            guard let service = apiService else {
                throw VideoAPIError.missingAPIKey
            }

            let fetchedVideos = try await service.listVideos()
            videos = fetchedVideos
            SoraPlannerLoggers.ui.info("Loaded \(fetchedVideos.count) videos")

            // Make individual status calls for failed videos to compare data
            let failedVideos = fetchedVideos.filter { $0.status == .failed }
            if !failedVideos.isEmpty {
                SoraPlannerLoggers.api.info("Making individual status calls for \(failedVideos.count) failed video(s) to compare with list endpoint")
                for video in failedVideos {
                    do {
                        SoraPlannerLoggers.api.info("Fetching individual status for failed video: \(video.id)")
                        _ = try await service.getVideoStatus(videoId: video.id)
                        // The raw JSON logging happens in getVideoStatus
                    } catch {
                        SoraPlannerLoggers.api.error("Failed to get individual status for video \(video.id): \(error.localizedDescription)")
                    }
                }
            }

            // Make individual status calls for long-queued videos (>5 minutes)
            let currentTime = Int(Date().timeIntervalSince1970)
            let longQueuedVideos = fetchedVideos.filter { video in
                video.status == .queued && (currentTime - video.createdAt) > 300
            }
            if !longQueuedVideos.isEmpty {
                SoraPlannerLoggers.api.info("Making individual status calls for \(longQueuedVideos.count) long-queued video(s) to compare with list endpoint")
                for video in longQueuedVideos {
                    do {
                        SoraPlannerLoggers.api.info("Fetching individual status for long-queued video: \(video.id)")
                        _ = try await service.getVideoStatus(videoId: video.id)
                        // The raw JSON logging happens in getVideoStatus
                    } catch {
                        SoraPlannerLoggers.api.error("Failed to get individual status for video \(video.id): \(error.localizedDescription)")
                    }
                }
            }

        } catch {
            SoraPlannerLoggers.ui.error("Failed to load videos: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false

        // Start polling for active videos
        startPollingIfNeeded()
    }

    /// Refresh the video list
    func refresh() async {
        await loadVideos()
    }

    /// Delete a video from the library
    func deleteVideo(_ video: VideoJob) async {
        guard let service = apiService else {
            SoraPlannerLoggers.ui.error("Cannot delete video - API service not available")
            errorMessage = "API service not available"
            return
        }

        SoraPlannerLoggers.ui.info("Deleting video: \(video.id)")

        // Mark as deleting
        deletingVideoIds.insert(video.id)

        do {
            try await service.deleteVideo(videoId: video.id)
            // Remove from local list
            videos.removeAll { $0.id == video.id }
            deletingVideoIds.remove(video.id)
            SoraPlannerLoggers.ui.info("Video deleted from library: \(video.id)")
        } catch {
            deletingVideoIds.remove(video.id)
            SoraPlannerLoggers.ui.error("Failed to delete video: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Save a video to the Photos library
    func saveToPhotos(_ video: VideoJob) async throws {
        guard let service = apiService else {
            throw VideoAPIError.missingAPIKey
        }

        guard video.status == .completed else {
            throw NSError(
                domain: "SoraPlanner",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Video must be completed before saving to Photos"]
            )
        }

        // Check current authorization status (using legacy API for macOS compatibility)
        let currentStatus = PHPhotoLibrary.authorizationStatus()
        SoraPlannerLoggers.video.info("Current Photos library authorization status: \(currentStatus.rawValue)")

        // Request permission using legacy API (works better on macOS)
        SoraPlannerLoggers.video.info("Requesting Photos library permission for video: \(video.id)")
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        SoraPlannerLoggers.video.info("Photos library authorization status after request: \(status.rawValue)")

        guard status == .authorized || status == .limited else {
            SoraPlannerLoggers.video.error("Photos library permission denied or restricted. Status: \(status.rawValue)")

            let errorMessage: String
            switch status {
            case .notDetermined:
                errorMessage = "Photo library permission was not determined. Please try again."
            case .restricted:
                errorMessage = "Photo library access is restricted. This may be due to parental controls or device management."
            case .denied:
                errorMessage = "Permission to access Photos library was denied. Please grant access in System Settings > Privacy & Security > Photos."
            default:
                errorMessage = "Unable to access Photos library. Please check System Settings > Privacy & Security > Photos."
            }

            throw NSError(
                domain: "SoraPlanner",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }

        // Mark as saving
        savingVideoIds.insert(video.id)
        defer { savingVideoIds.remove(video.id) }

        SoraPlannerLoggers.video.info("Downloading video for Photos save: \(video.id)")

        // Download video
        let videoURL = try await service.downloadVideo(videoId: video.id)

        SoraPlannerLoggers.video.info("Saving video to Photos library: \(videoURL.path)")

        // Save to Photos library
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }

        SoraPlannerLoggers.video.info("Successfully saved video \(video.id) to Photos library")
    }

    // MARK: - Polling Methods

    /// Start polling for all videos in active states (queued or in_progress)
    func startPollingIfNeeded() {
        let activeVideos = videos.filter { video in
            video.status == .queued || video.status == .inProgress
        }

        guard !activeVideos.isEmpty else {
            SoraPlannerLoggers.api.debug("No active videos to poll")
            return
        }

        // Limit concurrent polls
        let videosToStartPolling = activeVideos.prefix(maxConcurrentPolls)
        SoraPlannerLoggers.api.info("Starting polling for \(videosToStartPolling.count) active video(s)")

        for video in videosToStartPolling {
            // Only start polling if not already polling
            if pollingTasks[video.id] == nil {
                startPollingForVideo(video.id)
            }
        }
    }

    /// Start polling for a specific video
    func startPollingForVideo(_ videoId: String) {
        // Cancel existing task if any
        pollingTasks[videoId]?.cancel()

        SoraPlannerLoggers.api.info("Starting polling for video: \(videoId)")

        pollingTasks[videoId] = Task { @MainActor in
            var backoffMultiplier: TimeInterval = 1.0
            let maxBackoff: TimeInterval = 8.0

            while !Task.isCancelled {
                do {
                    try Task.checkCancellation()

                    guard let service = self.apiService else {
                        SoraPlannerLoggers.api.error("API service not available for polling video: \(videoId)")
                        self.stopPollingForVideo(videoId)
                        break
                    }

                    let updatedJob = try await service.getVideoStatus(videoId: videoId)

                    try Task.checkCancellation()

                    self.updateVideoStatus(videoId: videoId, newJob: updatedJob)

                    // Reset backoff on success
                    backoffMultiplier = 1.0

                    // Stop if terminal state
                    if updatedJob.status == .completed || updatedJob.status == .failed {
                        SoraPlannerLoggers.api.info("Video \(videoId) reached terminal state: \(updatedJob.status.rawValue)")
                        self.stopPollingForVideo(videoId)
                        break
                    }

                    SoraPlannerLoggers.api.debug("Polling successful for \(videoId), sleeping for \(self.pollingInterval)s")
                    try await Task.sleep(for: .seconds(self.pollingInterval))

                } catch is CancellationError {
                    SoraPlannerLoggers.api.debug("Polling cancelled for video: \(videoId)")
                    break
                } catch let error as VideoAPIError {
                    switch error {
                    case .missingAPIKey, .invalidURL:
                        // Fatal errors - stop polling
                        SoraPlannerLoggers.api.error("Fatal error polling video \(videoId): \(error.localizedDescription)")
                        self.stopPollingForVideo(videoId)
                        break
                    case .httpError(let statusCode, _):
                        if statusCode == 404 {
                            // Video deleted - remove from list and stop polling
                            SoraPlannerLoggers.api.warning("Video \(videoId) not found (404) - removing from list")
                            self.videos.removeAll { $0.id == videoId }
                            self.stopPollingForVideo(videoId)
                            break
                        } else {
                            // Transient HTTP error - retry with backoff
                            SoraPlannerLoggers.api.warning("HTTP error \(statusCode) polling video \(videoId) - retrying with backoff")
                            backoffMultiplier = min(backoffMultiplier * 2, maxBackoff)
                            try? await Task.sleep(for: .seconds(self.pollingInterval * backoffMultiplier))
                        }
                    case .networkError, .invalidResponse, .decodingError:
                        // Transient errors - retry with backoff
                        SoraPlannerLoggers.api.warning("Transient error polling video \(videoId): \(error.localizedDescription) - retrying with backoff")
                        backoffMultiplier = min(backoffMultiplier * 2, maxBackoff)
                        try? await Task.sleep(for: .seconds(self.pollingInterval * backoffMultiplier))
                    }
                } catch {
                    // Unknown error - log and retry with backoff
                    SoraPlannerLoggers.api.error("Unknown error polling video \(videoId): \(error.localizedDescription) - retrying with backoff")
                    backoffMultiplier = min(backoffMultiplier * 2, maxBackoff)
                    try? await Task.sleep(for: .seconds(self.pollingInterval * backoffMultiplier))
                }
            }

            self.pollingTasks.removeValue(forKey: videoId)
            SoraPlannerLoggers.api.debug("Polling task cleaned up for video: \(videoId)")
        }
    }

    /// Stop polling for a specific video
    func stopPollingForVideo(_ videoId: String) {
        guard let task = pollingTasks[videoId] else {
            return
        }

        SoraPlannerLoggers.api.info("Stopping polling for video: \(videoId)")
        task.cancel()
        pollingTasks.removeValue(forKey: videoId)
    }

    /// Stop all polling tasks (called when view disappears)
    func stopAllPolling() {
        guard !pollingTasks.isEmpty else {
            return
        }

        SoraPlannerLoggers.api.info("Stopping all polling tasks (\(self.pollingTasks.count) active)")

        for (videoId, task) in pollingTasks {
            SoraPlannerLoggers.api.debug("Cancelling polling task for video: \(videoId)")
            task.cancel()
        }

        pollingTasks.removeAll()
    }

    /// Update a specific video's status atomically
    private func updateVideoStatus(videoId: String, newJob: VideoJob) {
        guard let index = videos.firstIndex(where: { $0.id == videoId }) else {
            SoraPlannerLoggers.api.warning("Attempted to update status for unknown video: \(videoId)")
            return
        }

        let oldStatus = videos[index].status
        videos[index] = newJob

        if oldStatus != newJob.status {
            SoraPlannerLoggers.api.info("Video \(videoId) status updated: \(oldStatus.rawValue) -> \(newJob.status.rawValue)")
        } else {
            SoraPlannerLoggers.api.debug("Video \(videoId) status unchanged: \(newJob.status.rawValue)")
        }
    }

    // MARK: - Helper Methods

    /// Get a user-friendly status description
    func statusDescription(for video: VideoJob) -> String {
        switch video.status {
        case .queued:
            return "Queued"
        case .inProgress:
            if let progress = video.progress {
                return "Processing: \(progress)%"
            }
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    /// Get status color
    func statusColor(for video: VideoJob) -> String {
        switch video.status {
        case .queued:
            return "blue"
        case .inProgress:
            return "orange"
        case .completed:
            return "green"
        case .failed:
            return "red"
        }
    }

    /// Format timestamp to readable date
    func formattedDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
