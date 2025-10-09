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
    init(initialPrompt: String? = nil) {
        SoraPlannerLoggers.ui.info("VideoGenerationViewModel initialized")

        // Set initial prompt if provided
        if let prompt = initialPrompt, !prompt.isEmpty {
            self.prompt = prompt
            SoraPlannerLoggers.ui.debug("Initial prompt set: \(prompt.prefix(50))...")
        }

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
    /// Returns true if generation was successful, false otherwise
    func generateVideo() async -> Bool {
        guard canGenerate else {
            SoraPlannerLoggers.ui.warning("Cannot generate: invalid state")
            return false
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

            // Reset the form
            prompt = ""
            duration = 4
            successMessage = nil
            isGenerating = false

            return true

        } catch {
            SoraPlannerLoggers.ui.error("Failed to create video job: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isGenerating = false
            return false
        }
    }

    // MARK: - Cleanup
    nonisolated deinit {
        print("VideoGenerationViewModel deinitialized")
    }
}
