# SoraPlanner

SoraPlanner is a macOS application for planning and managing video generations using OpenAI's Sora-2 video API.

## Project Overview

This application provides a native macOS interface for creating, tracking, and managing AI-generated videos through OpenAI's video generation platform.

## Core Features

### Video Prompt Management
- Create and edit text prompts for video generation
- Configure video parameters (duration, resolution, quality)
- Save and organize prompts for reuse

### Video Generation
- Submit video generation jobs to OpenAI's Sora-2 API
- Monitor generation progress and status
- Handle queued, processing, completed, and failed states

### Video Library
- List all generated videos with metadata
- View video details (status, duration, resolution, creation date)
- Download completed videos
- Delete videos and manage storage

## Technical Stack

- **Platform**: macOS (macOS 26.0+)
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **API**: OpenAI Video API (Sora-2)
- **Architecture**: SwiftUI with modern concurrency (@MainActor isolation)

## API Integration

The application integrates with OpenAI's Video API endpoints:
- `POST /v1/videos` - Create video generation jobs
- `GET /v1/videos` - List video jobs
- `GET /v1/videos/{video_id}` - Retrieve video job details
- `GET /v1/videos/{video_id}/content` - Download video content
- `DELETE /v1/videos/{video_id}` - Delete videos

## Project Structure

- **SoraPlanner/**: Main application target
- **SoraPlannerTests/**: Unit tests
- **SoraPlannerUITests/**: UI tests
- **internal_docs/**: API documentation and reference materials

## Development Guidelines

- Always build after making changes to verify compilation
- Follow SwiftUI best practices for state management
- Use async/await for API calls
- Implement proper error handling for API failures
