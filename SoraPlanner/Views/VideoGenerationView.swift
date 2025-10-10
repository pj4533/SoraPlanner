//
//  VideoGenerationView.swift
//  SoraPlanner
//
//  View for generating new videos
//

import SwiftUI
import AVKit

struct VideoGenerationView: View {
    @StateObject private var viewModel: VideoGenerationViewModel
    @EnvironmentObject var playerCoordinator: VideoPlayerCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showAdvancedOptions = false

    let onGenerationSuccess: () -> Void

    init(initialPrompt: String?, onGenerationSuccess: @escaping () -> Void) {
        self.onGenerationSuccess = onGenerationSuccess
        // Create the view model with the initial prompt
        self._viewModel = StateObject(wrappedValue: VideoGenerationViewModel(initialPrompt: initialPrompt))
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header with Cancel button
            HStack {
                Text("Video Generation")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal)
            .padding(.top)

            // Prompt Input Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Prompt")
                    .font(.headline)

                TextEditor(text: $viewModel.prompt)
                    .frame(minHeight: 100, maxHeight: 150)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(viewModel.isGenerating)

                Text("Describe the video you want to generate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Duration Picker Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Duration")
                    .font(.headline)

                Picker("Duration", selection: $viewModel.duration) {
                    Text("4 seconds").tag(4)
                    Text("8 seconds").tag(8)
                    Text("12 seconds").tag(12)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isGenerating)

                HStack {
                    Text("Select the length of your generated video")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("Estimated: $\(String(format: "%.2f", viewModel.estimatedCost))")
                        .font(.callout)
                        .foregroundColor(.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)

            // Advanced Options Disclosure
            VStack(alignment: .leading, spacing: 0) {
                // Custom disclosure header with larger tap area
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvancedOptions.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showAdvancedOptions ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Advanced Options")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Expandable content
                if showAdvancedOptions {
                    VStack(spacing: 16) {
                        // Model Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Model", selection: $viewModel.model) {
                                Text("Sora-2 ($0.10/s)").tag("sora-2")
                                Text("Sora-2 Pro ($0.30/s - $0.50/s)").tag("sora-2-pro")
                            }
                            .pickerStyle(.segmented)
                            .disabled(viewModel.isGenerating)
                            .onChange(of: viewModel.model) { _, _ in
                                viewModel.validateResolution()
                            }
                        }

                        Divider()

                        // Resolution Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output Resolution")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Resolution", selection: $viewModel.resolution) {
                                Text("720x1280 (Portrait)").tag("720x1280")
                                Text("1280x720 (Landscape)").tag("1280x720")

                                if viewModel.model == "sora-2-pro" {
                                    Text("1024x1792 (High-Res Portrait)").tag("1024x1792")
                                    Text("1792x1024 (High-Res Landscape)").tag("1792x1024")
                                }
                            }
                            .disabled(viewModel.isGenerating)

                            if viewModel.model == "sora-2" {
                                Text("Higher resolutions require Sora-2 Pro")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if viewModel.isHighResProResolution {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("High-resolution output: $0.50 per second")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal)

            // Generate Button
            Button(action: {
                Task {
                    let success = await viewModel.generateVideo()
                    if success {
                        // Dismiss immediately and notify parent
                        dismiss()
                        onGenerationSuccess()
                    }
                }
            }) {
                HStack {
                    if viewModel.isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 4)
                    }
                    Text(viewModel.isGenerating ? "Submitting..." : "Generate Video")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canGenerate ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!viewModel.canGenerate)
            .padding(.horizontal)

            // Success Message
            if let successMessage = viewModel.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Error Display
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            Spacer()
        }
        .frame(minWidth: 600, minHeight: 600)
        .onAppear {
            // Retry API service initialization in case user just added API key in Settings
            viewModel.retryAPIServiceInitialization()
        }
    }
}

#Preview {
    VideoGenerationView(initialPrompt: nil, onGenerationSuccess: {})
        .environmentObject(VideoPlayerCoordinator())
}
