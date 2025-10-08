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

        } catch {
            SoraPlannerLoggers.ui.error("Failed to load videos: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

        SoraPlannerLoggers.video.info("Requesting Photos library permission for video: \(video.id)")

        // Request permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized else {
            SoraPlannerLoggers.video.error("Photos library permission denied")
            throw NSError(
                domain: "SoraPlanner",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Permission to access Photos library was denied. Please grant access in System Settings."]
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
