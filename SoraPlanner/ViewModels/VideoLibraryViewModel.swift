//
//  VideoLibraryViewModel.swift
//  SoraPlanner
//
//  ViewModel for managing video library state
//

import Foundation
import Combine
import os

@MainActor
class VideoLibraryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var videos: [VideoJob] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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
