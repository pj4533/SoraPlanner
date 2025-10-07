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
                    Text(viewModel.isGenerating ? "Generating..." : "Generate Video")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canGenerate ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!viewModel.canGenerate)
            .padding(.horizontal)

            // Status Section
            if viewModel.isGenerating || viewModel.currentVideoJob != nil {
                VStack(spacing: 12) {
                    // Animated Progress Indicator
                    if viewModel.isGenerating {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                            .symbolEffect(.rotate, options: .repeating)
                    }

                    // Status Message
                    Text(viewModel.statusMessage)
                        .font(.headline)
                        .foregroundColor(.secondary)

                    // Progress Bar (if available)
                    if let job = viewModel.currentVideoJob,
                       let progress = job.progress {
                        ProgressView(value: Double(progress), total: 100.0)
                            .frame(maxWidth: 300)
                        Text("\(progress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
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

            // Video Ready - Show Play Button
            if let job = viewModel.currentVideoJob, job.status == .completed {
                VStack(spacing: 12) {
                    Text("Video Ready!")
                        .font(.headline)
                        .foregroundColor(.green)

                    Button(action: {
                        Task {
                            await playerCoordinator.play(job)
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Play Video")
                        }
                        .font(.title3)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }

            Spacer()

            // Cancel Button (shown during generation)
            if viewModel.isGenerating {
                Button("Cancel Generation") {
                    viewModel.cancelGeneration()
                }
                .foregroundColor(.red)
                .padding(.bottom)
            }
        }
        .frame(minWidth: 600, minHeight: 700)
    }
}

#Preview {
    VideoGenerationView()
        .environmentObject(VideoPlayerCoordinator())
}
