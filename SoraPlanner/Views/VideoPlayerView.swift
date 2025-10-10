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
        ZStack {
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
                    .cornerRadius(8)
            }

            // Overlay close button and metadata
            VStack {
                // Top bar with close button
                HStack {
                    Spacer()
                    Button(action: {
                        coordinator.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }

                Spacer()

                // Bottom metadata overlay (only shown when video is playing)
                if coordinator.videoURL != nil {
                    HStack(spacing: 16) {
                        if let size = video.size {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle.expand.vertical")
                                Text(size)
                            }
                        }

                        if let seconds = video.seconds {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                Text("\(seconds)s")
                            }
                        }

                        if let quality = video.quality {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text(quality)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .task {
            // Auto-load video when view appears
            if coordinator.videoURL == nil && !coordinator.isLoading {
                await coordinator.play(video)
            }
        }
    }
}
