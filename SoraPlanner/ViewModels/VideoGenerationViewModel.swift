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
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Private Properties
    private var apiService: VideoAPIService?

    // MARK: - Computed Properties
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

    /// Start video generation process
    func generateVideo() async {
        guard canGenerate else {
            SoraPlannerLoggers.ui.warning("Cannot generate: invalid state")
            return
        }

        SoraPlannerLoggers.ui.info("Starting video generation")

        isGenerating = true
        errorMessage = nil
        successMessage = nil

        do {
            guard let service = apiService else {
                throw VideoAPIError.missingAPIKey
            }

            // Create video job
            let job = try await service.createVideo(prompt: prompt, seconds: String(duration))

            SoraPlannerLoggers.ui.info("Video job created: \(job.id)")

            // Show success message
            successMessage = "Video queued! Check the Library tab for status."

            // Reset form after brief delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Reset the form
            prompt = ""
            duration = 4
            successMessage = nil
            isGenerating = false

        } catch {
            SoraPlannerLoggers.ui.error("Failed to create video job: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }

    // MARK: - Cleanup
    nonisolated deinit {
        print("VideoGenerationViewModel deinitialized")
    }
}
