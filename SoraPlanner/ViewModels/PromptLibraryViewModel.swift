//
//  PromptLibraryViewModel.swift
//  SoraPlanner
//
//  ViewModel for managing the prompt library with persistent storage
//

import Foundation
import Combine
import os

@MainActor
class PromptLibraryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var prompts: [Prompt] = []
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let userDefaultsKey = "saved_prompts"
    private let logger = SoraPlannerLoggers.ui

    // MARK: - Initialization
    init() {
        logger.info("PromptLibraryViewModel initialized")
        loadPrompts()
    }

    // MARK: - Public Methods

    /// Add a new empty prompt to the library
    func addPrompt() {
        logger.info("Adding new prompt")
        let newPrompt = Prompt()
        prompts.insert(newPrompt, at: 0) // Add at the top
        savePrompts()
    }

    /// Update an existing prompt
    func updatePrompt(_ prompt: Prompt) {
        logger.debug("Updating prompt: \(prompt.id)")
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            var updatedPrompt = prompt
            updatedPrompt.modifiedAt = Date()
            prompts[index] = updatedPrompt
            savePrompts()
        } else {
            logger.warning("Attempted to update non-existent prompt: \(prompt.id)")
        }
    }

    /// Delete a prompt from the library
    func deletePrompt(_ prompt: Prompt) {
        logger.info("Deleting prompt: \(prompt.id)")
        prompts.removeAll { $0.id == prompt.id }
        savePrompts()
    }

    /// Get a prompt by ID
    func getPrompt(byId id: UUID) -> Prompt? {
        return prompts.first { $0.id == id }
    }

    // MARK: - Private Methods

    /// Load prompts from UserDefaults
    private func loadPrompts() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            logger.info("No saved prompts found")
            prompts = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([Prompt].self, from: data)
            prompts = decoded.sorted { $0.createdAt > $1.createdAt } // Sort by newest first
            logger.info("Loaded \(self.prompts.count) prompts from storage")
        } catch {
            logger.error("Failed to load prompts: \(error.localizedDescription)")
            errorMessage = "Failed to load saved prompts: \(error.localizedDescription)"
            prompts = []
        }
    }

    /// Save prompts to UserDefaults
    private func savePrompts() {
        do {
            let data = try JSONEncoder().encode(prompts)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            logger.debug("Saved \(self.prompts.count) prompts to storage")
            errorMessage = nil
        } catch {
            logger.error("Failed to save prompts: \(error.localizedDescription)")
            errorMessage = "Failed to save prompts: \(error.localizedDescription)"
        }
    }
}
