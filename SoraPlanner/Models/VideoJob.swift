//
//  VideoJob.swift
//  SoraPlanner
//
//  Models for OpenAI Video API responses
//

import Foundation

/// Current lifecycle status of a video job
enum VideoStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
}

/// Error details for failed video generation
struct VideoError: Codable {
    let code: String
    let message: String
}

/// Video job object representing a video generation request
struct VideoJob: Codable, Identifiable {
    let id: String
    let object: String
    let model: String
    let status: VideoStatus
    let progress: Int?
    let createdAt: Int
    let completedAt: Int?
    let expiresAt: Int?
    let error: VideoError?
    let remixedFromVideoId: String?
    let seconds: String?
    let size: String?
    let quality: String?

    enum CodingKeys: String, CodingKey {
        case id, object, model, status, progress, error, seconds, size, quality
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case expiresAt = "expires_at"
        case remixedFromVideoId = "remixed_from_video_id"
    }
}

/// Response for list videos endpoint
struct VideoListResponse: Codable {
    let data: [VideoJob]
    let object: String
}

/// Request body for creating a video
struct CreateVideoRequest: Codable {
    let model: String
    let prompt: String
    let seconds: String?

    init(prompt: String, seconds: String? = nil) {
        self.model = "sora-2"
        self.prompt = prompt
        self.seconds = seconds
    }
}
