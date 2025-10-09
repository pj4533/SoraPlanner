//
//  VideoGenerationView.swift
//  SoraPlanner
//
//  View for generating new videos
//

import SwiftUI
import AVKit

struct VideoGenerationView: View {
    @StateObject private var viewModel = VideoGenerationViewModel()
    @EnvironmentObject var playerCoordinator: VideoPlayerCoordinator
    @Environment(\.dismiss) private var dismiss

    let initialPrompt: String?

    var body: some View {
        VStack(spacing: 20) {
            // App Title
            Text("Video Generation")
                .font(.largeTitle)
                .fontWeight(.bold)
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

                HStack(spacing: 16) {
                    Picker("Duration", selection: $viewModel.duration) {
                        Text("4 seconds").tag(4)
                        Text("8 seconds").tag(8)
                        Text("12 seconds").tag(12)
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isGenerating)

                    Text("\(viewModel.duration)s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 35)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Select the length of your generated video")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Sora-2 model • $0.10 per second")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Generate Button
            Button(action: {
                Task {
                    await viewModel.generateVideo()
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
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            // Set initial prompt if provided
            if let prompt = initialPrompt {
                viewModel.prompt = prompt
            }
            // Retry API service initialization in case user just added API key in Settings
            viewModel.retryAPIServiceInitialization()
        }
        .onChange(of: viewModel.successMessage) { oldValue, newValue in
            // Dismiss modal after successful generation
            if newValue != nil {
                Task {
                    // Wait for success message to be shown
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    VideoGenerationView(initialPrompt: nil)
        .environmentObject(VideoPlayerCoordinator())
}
