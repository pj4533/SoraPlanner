//
//  VideoPlayerView.swift
//  SoraPlanner
//
//  Reusable video player component
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: VideoJob
    @EnvironmentObject var coordinator: VideoPlayerCoordinator

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video Player")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("ID: \(video.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    coordinator.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Content
            if coordinator.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading video...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = coordinator.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Close") {
                        coordinator.dismiss()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let videoURL = coordinator.videoURL {
                // Video Player - Using custom looping player for seamless playback
                LoopingVideoPlayerView(url: videoURL)
                    .frame(minHeight: 400)
                    .cornerRadius(12)
                    .padding()

                // Video Info
                VStack(alignment: .leading, spacing: 8) {
                    if let size = video.size {
                        HStack {
                            Image(systemName: "rectangle.expand.vertical")
                            Text("Resolution: \(size)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let seconds = video.seconds {
                        HStack {
                            Image(systemName: "timer")
                            Text("Duration: \(seconds) seconds")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let quality = video.quality {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Quality: \(quality)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }

            Spacer()
        }
        .frame(minWidth: 700, minHeight: 600)
        .task {
            // Auto-load video when view appears
            if coordinator.videoURL == nil && !coordinator.isLoading {
                await coordinator.play(video)
            }
        }
    }
}
