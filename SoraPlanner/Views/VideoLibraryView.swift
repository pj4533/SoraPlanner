//
//  VideoLibraryView.swift
//  SoraPlanner
//
//  View for displaying the video library
//

import SwiftUI

struct VideoLibraryView: View {
    @StateObject private var viewModel = VideoLibraryViewModel()
    @EnvironmentObject var playerCoordinator: VideoPlayerCoordinator

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Video Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .disabled(viewModel.isLoading)
            }
            .padding()

            Divider()

            // Content
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading videos...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Error Loading Videos")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadVideos()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if viewModel.videos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Videos Yet")
                        .font(.headline)
                    Text("Generate your first video to see it here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                // Video List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.videos) { video in
                            VideoLibraryRow(video: video, viewModel: viewModel)
                                .onTapGesture {
                                    Task {
                                        await playerCoordinator.play(video)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .task {
            await viewModel.loadVideos()
        }
    }
}

struct VideoLibraryRow: View {
    let video: VideoJob
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack {
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusDescription(for: video))
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                // Video ID
                Text("ID: \(video.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Video Details
            if video.status == .processing, let progress = video.progress {
                ProgressView(value: Double(progress), total: 100.0)
                    .frame(height: 4)
                Text("\(progress)% complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Metadata
            HStack(spacing: 16) {
                if let size = video.size {
                    Label(size, systemImage: "rectangle.expand.vertical")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let seconds = video.seconds {
                    Label("\(seconds)s", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let quality = video.quality {
                    Label(quality, systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Created Date
            Text("Created: \(viewModel.formattedDate(video.createdAt))")
                .font(.caption2)
                .foregroundColor(.secondary)

            // Error Message (if failed)
            if video.status == .failed, let error = video.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error.message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }

            // Completion Date
            if video.status == .completed, let completedAt = video.completedAt {
                Text("Completed: \(viewModel.formattedDate(completedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Expiration Warning
            if let expiresAt = video.expiresAt {
                let expirationDate = Date(timeIntervalSince1970: TimeInterval(expiresAt))
                if expirationDate > Date() {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("Expires: \(viewModel.formattedDate(expiresAt))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(video.status == .completed ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .help(video.status == .completed ? "Tap to play video" : "Video not ready for playback")
    }

    private var statusColor: Color {
        switch viewModel.statusColor(for: video) {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        default: return .gray
        }
    }
}

#Preview {
    VideoLibraryView()
        .environmentObject(VideoPlayerCoordinator())
}
