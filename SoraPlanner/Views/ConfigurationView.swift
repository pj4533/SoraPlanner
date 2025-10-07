//
//  ConfigurationView.swift
//  SoraPlanner
//
//  Configuration and settings interface for the application.
//

import SwiftUI
import os.log

struct ConfigurationView: View {
    @State private var apiKey: String = ""
    @State private var isKeyStored: Bool = false
    @State private var showingSuccess: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    private let logger = SoraPlannerLoggers.ui
    private let keychainService = KeychainService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                    .padding(.top, 40)

                Text("API Configuration")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Store your OpenAI API key securely in your macOS Keychain")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 30)

            // Configuration Form
            VStack(alignment: .leading, spacing: 20) {
                // Status Indicator
                HStack {
                    Image(systemName: isKeyStored ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isKeyStored ? .green : .orange)
                    Text(isKeyStored ? "API Key Stored" : "No API Key Stored")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal)

                // API Key Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.headline)

                    SecureField("sk-proj-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Get your API key from")
                        Link("platform.openai.com", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: saveAPIKey) {
                        Label(isKeyStored ? "Update Key" : "Save Key", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if isKeyStored {
                        Button(role: .destructive, action: deleteAPIKey) {
                            Label("Delete Key", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                // Success/Error Messages
                if showingSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("API key saved successfully")
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }

                if showingError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)

            Spacer()

            // Footer Information
            VStack(spacing: 12) {
                Divider()

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Your API key is encrypted and stored securely in macOS Keychain")
                    }

                    HStack {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.blue)
                        Text("Keys are never logged or transmitted anywhere except to OpenAI")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkStoredKey()
        }
    }

    // MARK: - Actions

    private func checkStoredKey() {
        isKeyStored = keychainService.hasAPIKey()
        logger.debug("Checked keychain - API key stored: \(self.isKeyStored)")
    }

    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            showError("API key cannot be empty")
            return
        }

        do {
            try keychainService.saveAPIKey(trimmedKey)
            logger.info("API key saved successfully")

            // Clear input and update UI
            apiKey = ""
            isKeyStored = true
            showSuccess()
        } catch {
            logger.error("Failed to save API key: \(error.localizedDescription)")
            showError("Failed to save API key: \(error.localizedDescription)")
        }
    }

    private func deleteAPIKey() {
        do {
            try keychainService.deleteAPIKey()
            logger.info("API key deleted successfully")

            // Update UI
            apiKey = ""
            isKeyStored = false
            showSuccess()
        } catch {
            logger.error("Failed to delete API key: \(error.localizedDescription)")
            showError("Failed to delete API key: \(error.localizedDescription)")
        }
    }

    private func showSuccess() {
        showingSuccess = true
        showingError = false

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingSuccess = false
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
        showingSuccess = false

        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            showingError = false
        }
    }
}

#Preview {
    ConfigurationView()
}
