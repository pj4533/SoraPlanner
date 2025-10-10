//
//  VideoAPIService.swift
//  SoraPlanner
//
//  Service layer for OpenAI Video API communication
//

import Foundation
import os

enum VideoAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Please add your OpenAI API key in the Settings tab."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}

@MainActor
class VideoAPIService {
    private let baseURL = "https://api.openai.com/v1/videos"
    private let apiKey: String

    init() throws {
        // Check keychain first (preferred method)
        if let key = KeychainService.shared.retrieveAPIKey(), !key.isEmpty {
            self.apiKey = key
            SoraPlannerLoggers.api.info("VideoAPIService initialized with API key from keychain")
        }
        // Fall back to environment variable (for backward compatibility)
        else if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            self.apiKey = key
            SoraPlannerLoggers.api.info("VideoAPIService initialized with API key from environment variable")
        }
        else {
            SoraPlannerLoggers.api.error("No API key found in keychain or environment variables")
            throw VideoAPIError.missingAPIKey
        }
    }

    /// Create a new video generation job
    func createVideo(prompt: String, model: String = "sora-2", seconds: String? = nil, size: String? = nil) async throws -> VideoJob {
        SoraPlannerLoggers.api.info("Creating video job with model: \(model), size: \(size ?? "default"), prompt: \(prompt.prefix(50))...")

        guard let url = URL(string: baseURL) else {
            SoraPlannerLoggers.api.error("Invalid base URL")
            throw VideoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = CreateVideoRequest(prompt: prompt, model: model, seconds: seconds, size: size)
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        do {
            guard let httpResponse = response as? HTTPURLResponse else {
                SoraPlannerLoggers.api.error("Invalid response type")
                throw VideoAPIError.invalidResponse
            }

            SoraPlannerLoggers.networking.debug("HTTP \(httpResponse.statusCode) response received")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                SoraPlannerLoggers.api.error("HTTP error \(httpResponse.statusCode): \(errorMessage)")
                throw VideoAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let videoJob = try JSONDecoder().decode(VideoJob.self, from: data)
            SoraPlannerLoggers.api.info("Video job created successfully: \(videoJob.id)")
            return videoJob

        } catch let error as VideoAPIError {
            throw error
        } catch let error as DecodingError {
            logDecodingError(error, data: data, context: "POST /v1/videos")
            throw VideoAPIError.decodingError(error)
        } catch {
            SoraPlannerLoggers.api.error("Network error: \(error.localizedDescription)")
            throw VideoAPIError.networkError(error)
        }
    }

    /// Retrieve the status of a video job
    func getVideoStatus(videoId: String) async throws -> VideoJob {
        SoraPlannerLoggers.api.debug("Fetching status for video: \(videoId)")

        guard let url = URL(string: "\(baseURL)/\(videoId)") else {
            SoraPlannerLoggers.api.error("Invalid video URL")
            throw VideoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        do {
            guard let httpResponse = response as? HTTPURLResponse else {
                SoraPlannerLoggers.api.error("Invalid response type")
                throw VideoAPIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                SoraPlannerLoggers.api.error("HTTP error \(httpResponse.statusCode): \(errorMessage)")
                throw VideoAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let videoJob = try JSONDecoder().decode(VideoJob.self, from: data)

            // Enhanced logging for different status states
            switch videoJob.status {
            case .failed:
                // Log comprehensive failure information including raw JSON
                let rawJSON = String(data: data, encoding: .utf8) ?? "Unable to decode raw JSON"
                SoraPlannerLoggers.api.error("❌ Video FAILED - ID: \(videoId)")
                SoraPlannerLoggers.api.error("Failed video error code: \(videoJob.error?.code ?? "none")")
                SoraPlannerLoggers.api.error("Failed video error message: \(videoJob.error?.message ?? "none")")
                SoraPlannerLoggers.api.error("Failed video raw JSON: \(rawJSON)")

            case .queued:
                // Log detailed information about queued state to detect guardrails
                let rawJSON = String(data: data, encoding: .utf8) ?? "Unable to decode raw JSON"
                SoraPlannerLoggers.api.info("⏸️ Video QUEUED - ID: \(videoId)")
                SoraPlannerLoggers.api.info("Queued video created_at: \(videoJob.createdAt)")
                SoraPlannerLoggers.api.info("Queued video model: \(videoJob.model)")
                SoraPlannerLoggers.api.info("Queued video seconds: \(videoJob.seconds ?? "none")")
                SoraPlannerLoggers.api.info("Queued video size: \(videoJob.size ?? "none")")
                SoraPlannerLoggers.api.info("Queued video quality: \(videoJob.quality ?? "none")")
                if let error = videoJob.error {
                    SoraPlannerLoggers.api.warning("⚠️ Queued video has error field - code: \(error.code), message: \(error.message)")
                }
                SoraPlannerLoggers.api.info("Queued video raw JSON: \(rawJSON)")

            case .inProgress:
                SoraPlannerLoggers.api.debug("🔄 Video IN_PROGRESS - ID: \(videoId), progress: \(videoJob.progress ?? 0)%")

            case .completed:
                SoraPlannerLoggers.api.debug("✅ Video COMPLETED - ID: \(videoId)")
            }

            return videoJob

        } catch let error as VideoAPIError {
            throw error
        } catch let error as DecodingError {
            logDecodingError(error, data: data, context: "GET /v1/videos/\(videoId)")
            throw VideoAPIError.decodingError(error)
        } catch {
            SoraPlannerLoggers.api.error("Network error: \(error.localizedDescription)")
            throw VideoAPIError.networkError(error)
        }
    }

    /// Download the video content (MP4 file)
    func downloadVideo(videoId: String) async throws -> URL {
        SoraPlannerLoggers.video.info("Downloading video: \(videoId)")

        guard let url = URL(string: "\(baseURL)/\(videoId)/content") else {
            SoraPlannerLoggers.api.error("Invalid download URL")
            throw VideoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                SoraPlannerLoggers.api.error("Invalid response type")
                throw VideoAPIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                SoraPlannerLoggers.api.error("HTTP error \(httpResponse.statusCode): \(errorMessage)")
                throw VideoAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            // Save to temporary directory
            let tempDirectory = FileManager.default.temporaryDirectory
            let videoURL = tempDirectory.appendingPathComponent("\(videoId).mp4")

            try data.write(to: videoURL)
            SoraPlannerLoggers.video.info("Video saved to: \(videoURL.path)")

            return videoURL

        } catch let error as VideoAPIError {
            throw error
        } catch {
            SoraPlannerLoggers.api.error("Download error: \(error.localizedDescription)")
            throw VideoAPIError.networkError(error)
        }
    }

    /// Delete a video job
    func deleteVideo(videoId: String) async throws {
        SoraPlannerLoggers.api.info("Deleting video: \(videoId)")

        guard let url = URL(string: "\(baseURL)/\(videoId)") else {
            SoraPlannerLoggers.api.error("Invalid video URL")
            throw VideoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                SoraPlannerLoggers.api.error("Invalid response type")
                throw VideoAPIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                SoraPlannerLoggers.api.error("HTTP error \(httpResponse.statusCode): \(errorMessage)")
                throw VideoAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            SoraPlannerLoggers.api.info("Video deleted successfully: \(videoId)")

        } catch let error as VideoAPIError {
            throw error
        } catch {
            SoraPlannerLoggers.api.error("Delete error: \(error.localizedDescription)")
            throw VideoAPIError.networkError(error)
        }
    }

    /// List all video jobs
    func listVideos(limit: Int = 100) async throws -> [VideoJob] {
        SoraPlannerLoggers.api.info("Fetching video list")

        // Add pagination parameters to URL
        var urlComponents = URLComponents(string: baseURL)
        urlComponents?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = urlComponents?.url else {
            SoraPlannerLoggers.api.error("Invalid base URL")
            throw VideoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        do {
            guard let httpResponse = response as? HTTPURLResponse else {
                SoraPlannerLoggers.api.error("Invalid response type")
                throw VideoAPIError.invalidResponse
            }

            SoraPlannerLoggers.networking.debug("HTTP \(httpResponse.statusCode) response received")

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                SoraPlannerLoggers.api.error("HTTP error \(httpResponse.statusCode): \(errorMessage)")
                throw VideoAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let listResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
            SoraPlannerLoggers.api.info("Retrieved \(listResponse.data.count) videos")

            // Log summary of video statuses and detailed info for failed/queued videos
            let statusCounts = Dictionary(grouping: listResponse.data, by: { $0.status })
            SoraPlannerLoggers.api.info("Video status summary: queued=\(statusCounts[.queued]?.count ?? 0), in_progress=\(statusCounts[.inProgress]?.count ?? 0), completed=\(statusCounts[.completed]?.count ?? 0), failed=\(statusCounts[.failed]?.count ?? 0)")

            // Log detailed information for failed videos
            let failedVideos = listResponse.data.filter { $0.status == .failed }
            if !failedVideos.isEmpty {
                SoraPlannerLoggers.api.error("Found \(failedVideos.count) failed video(s) in library:")
                for video in failedVideos {
                    SoraPlannerLoggers.api.error("  ❌ Failed video ID: \(video.id)")
                    SoraPlannerLoggers.api.error("     Error code: \(video.error?.code ?? "none")")
                    SoraPlannerLoggers.api.error("     Error message: \(video.error?.message ?? "none")")
                    SoraPlannerLoggers.api.error("     Created at: \(video.createdAt), Model: \(video.model)")

                    // Log raw JSON for failed video
                    if let videoData = try? JSONEncoder().encode(video),
                       let videoJSON = String(data: videoData, encoding: .utf8) {
                        SoraPlannerLoggers.api.error("     Raw JSON: \(videoJSON)")
                    }
                }
            }

            // Log detailed information for queued videos (potential guardrail issues)
            let queuedVideos = listResponse.data.filter { $0.status == .queued }
            if !queuedVideos.isEmpty {
                SoraPlannerLoggers.api.info("Found \(queuedVideos.count) queued video(s) in library:")
                for video in queuedVideos {
                    let currentTime = Int(Date().timeIntervalSince1970)
                    let queuedDuration = currentTime - video.createdAt
                    SoraPlannerLoggers.api.info("  ⏸️ Queued video ID: \(video.id)")
                    SoraPlannerLoggers.api.info("     Queued duration: \(queuedDuration) seconds")
                    SoraPlannerLoggers.api.info("     Model: \(video.model), Seconds: \(video.seconds ?? "none"), Size: \(video.size ?? "none"), Quality: \(video.quality ?? "none")")
                    if let error = video.error {
                        SoraPlannerLoggers.api.warning("     ⚠️ Has error field - code: \(error.code), message: \(error.message)")
                    }
                    // Long-queued videos might indicate guardrail blocks
                    if queuedDuration > 300 { // 5 minutes
                        SoraPlannerLoggers.api.warning("     ⚠️ Video has been queued for over 5 minutes - possible API-side guardrail block")

                        // Log raw JSON for long-queued videos
                        if let videoData = try? JSONEncoder().encode(video),
                           let videoJSON = String(data: videoData, encoding: .utf8) {
                            SoraPlannerLoggers.api.warning("     Raw JSON: \(videoJSON)")
                        }
                    }
                }
            }

            return listResponse.data

        } catch let error as VideoAPIError {
            throw error
        } catch let error as DecodingError {
            logDecodingError(error, data: data, context: "GET /v1/videos")
            throw VideoAPIError.decodingError(error)
        } catch {
            SoraPlannerLoggers.api.error("Network error: \(error.localizedDescription)")
            throw VideoAPIError.networkError(error)
        }
    }
}
