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
            return "OPENAI_API_KEY environment variable not set"
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
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
            SoraPlannerLoggers.api.error("OPENAI_API_KEY environment variable not found")
            throw VideoAPIError.missingAPIKey
        }
        self.apiKey = key
        SoraPlannerLoggers.api.info("VideoAPIService initialized")
    }

    /// Create a new video generation job
    func createVideo(prompt: String, seconds: String? = nil) async throws -> VideoJob {
        SoraPlannerLoggers.api.info("Creating video job with prompt: \(prompt)")

        guard let url = URL(string: baseURL) else {
            SoraPlannerLoggers.api.error("Invalid base URL")
            throw VideoAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = CreateVideoRequest(prompt: prompt, seconds: seconds)
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
            SoraPlannerLoggers.api.debug("Video status: \(videoJob.status.rawValue), progress: \(videoJob.progress ?? 0)%")
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
