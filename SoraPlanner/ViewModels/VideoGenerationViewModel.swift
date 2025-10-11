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
    @Published var model: String = "sora-2" // Model selection: sora-2 or sora-2-pro
    @Published var resolution: String = "720x1280" // Output resolution
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Private Properties
    private let service: VideoAPIService

    // MARK: - Computed Properties
    var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    /// Available resolutions based on selected model
    var availableResolutions: [String] {
        var resolutions = ["720x1280", "1280x720"]
        if model == "sora-2-pro" {
            resolutions.append(contentsOf: ["1024x1792", "1792x1024"])
        }
        return resolutions
    }

    /// Check if current resolution is a high-res pro resolution
    var isHighResProResolution: Bool {
        model == "sora-2-pro" && (resolution == "1024x1792" || resolution == "1792x1024")
    }

    /// Price per second based on model and resolution
    var pricePerSecond: Double {
        if model == "sora-2" {
            return 0.10
        } else if isHighResProResolution {
            return 0.50
        } else {
            return 0.30
        }
    }

    /// Total estimated cost
    var estimatedCost: Double {
        pricePerSecond * Double(duration)
    }

    // MARK: - Initialization
    init(service: VideoAPIService, initialPrompt: String? = nil) {
        self.service = service

        // Set initial prompt if provided
        if let prompt = initialPrompt, !prompt.isEmpty {
            self.prompt = prompt
            SoraPlannerLoggers.ui.debug("Initial prompt set: \(prompt.prefix(50))...")
        }

        SoraPlannerLoggers.ui.info("VideoGenerationViewModel initialized")
    }

    // MARK: - Public Methods

    /// Start video generation process
    /// Returns true if generation was successful, false otherwise
    func generateVideo() async -> Bool {
        guard canGenerate else {
            SoraPlannerLoggers.ui.warning("Cannot generate: invalid state")
            return false
        }

        SoraPlannerLoggers.ui.info("Starting video generation with model: \(self.model), resolution: \(self.resolution)")

        isGenerating = true
        errorMessage = nil
        successMessage = nil

        do {
            // Create video job with model and resolution
            let job = try await service.createVideo(
                prompt: prompt,
                model: model,
                seconds: String(duration),
                size: resolution
            )

            SoraPlannerLoggers.ui.info("Video job created: \(job.id) with cost: $\(String(format: "%.2f", self.estimatedCost))")

            // Reset the form
            prompt = ""
            duration = 4
            model = "sora-2"
            resolution = "720x1280"
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

    /// Validate and adjust resolution when model changes
    func validateResolution() {
        // If switching to sora-2 and current resolution is a pro-only resolution, reset to default
        if model == "sora-2" && (resolution == "1024x1792" || resolution == "1792x1024") {
            resolution = "720x1280"
            SoraPlannerLoggers.ui.debug("Resolution reset to 720x1280 (pro resolution not available for sora-2)")
        }
    }

    // MARK: - Cleanup
    nonisolated deinit {
        print("VideoGenerationViewModel deinitialized")
    }
}
