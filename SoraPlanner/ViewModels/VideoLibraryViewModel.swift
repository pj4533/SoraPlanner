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
