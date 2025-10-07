# SoraPlanner

SoraPlanner is a macOS application for planning and managing video generations using OpenAI's Sora-2 video API.

## Project Overview

This application provides a native macOS interface for creating, tracking, and managing AI-generated videos through OpenAI's video generation platform. It features a tabbed interface with separate views for video generation and library management, integrated video playback, and real-time status polling for generation jobs.

## Core Features

### Video Generation Interface
- Interactive prompt editor with multi-line text support
- Duration selection (4, 10, or 30 seconds) with pricing information
- Real-time generation status monitoring with progress indicators
- Animated visual feedback during video processing
- Integrated error handling and user-friendly error messages
- Automatic status polling for queued and in-progress jobs
- Direct playback of completed videos

### Video Library Management
- Comprehensive list view of all generated videos
- Status badges with color-coded indicators (queued, processing, completed, failed)
- Detailed video metadata display (ID, duration, resolution, quality)
- Progress tracking for videos currently being generated
- Creation and completion timestamps
- Video expiration warnings
- Error message display for failed generations
- Tap-to-play functionality for completed videos
- Pull-to-refresh capability

### Video Playback
- Dedicated video player modal with AVKit integration
- Automatic video download on playback request
- Video metadata overlay (resolution, duration, quality)
- Shared coordinator pattern for consistent playback across tabs
- Loading states and error handling

## Technical Stack

- **Platform**: macOS 26.0+
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **API**: OpenAI Video API (Sora-2)
- **Architecture**: MVVM with @MainActor isolation for thread safety
- **Concurrency**: Swift modern concurrency (async/await, Task)
- **Media Playback**: AVKit and AVFoundation
- **Logging**: Apple's Unified Logging System (os.log)
- **Networking**: URLSession with async/await

## API Integration

The application integrates with OpenAI's Video API through a dedicated service layer:

**Supported Endpoints:**
- `POST /v1/videos` - Create video generation jobs
- `GET /v1/videos` - List video jobs with pagination
- `GET /v1/videos/{video_id}` - Retrieve video job details and status
- `GET /v1/videos/{video_id}/content` - Download video content (MP4)

**API Features:**
- Bearer token authentication via OPENAI_API_KEY environment variable
- Comprehensive error handling with typed error cases
- Automatic retry logic through polling mechanism
- Detailed request/response logging
- Decoding error logging with raw JSON output for debugging

## Project Structure

```
SoraPlanner/
├── SoraPlannerApp.swift           # Main app entry point
├── ContentView.swift               # Root view with tab navigation and player coordinator
├── Models/
│   └── VideoJob.swift             # Core data models (VideoJob, VideoStatus, VideoError)
├── Services/
│   └── VideoAPIService.swift      # OpenAI Video API client
├── ViewModels/
│   ├── VideoGenerationViewModel.swift   # Business logic for video generation
│   ├── VideoLibraryViewModel.swift      # Business logic for video library
│   └── VideoPlayerCoordinator.swift     # Shared video playback coordinator
├── Views/
│   ├── VideoGenerationView.swift  # Video creation interface
│   ├── VideoLibraryView.swift     # Video list and management interface
│   └── VideoPlayerView.swift      # Video playback modal
├── Utilities/
│   ├── Logging.swift              # Centralized logging configuration
│   └── DecodingErrorLogger.swift  # JSON decoding error utilities
└── Assets.xcassets/               # App icons and accent colors

SoraPlannerTests/                  # Unit test target
SoraPlannerUITests/                # UI test target
internal_docs/                     # API documentation and reference materials
```

## Architecture Patterns

### MVVM (Model-View-ViewModel)
- **Models**: Codable structs for API request/response (VideoJob, CreateVideoRequest, etc.)
- **ViewModels**: Observable objects managing business logic and state (@MainActor isolated)
- **Views**: SwiftUI views with declarative UI and data binding

### Coordinator Pattern
- `VideoPlayerCoordinator` manages shared video playback state across tabs
- Injected via SwiftUI environment object
- Handles video download and presentation logic

### Service Layer
- `VideoAPIService` encapsulates all API communication
- Throws typed errors for proper error handling
- Configured via environment variables for security

### Logging Subsystems
- `api` - API requests, responses, and errors
- `ui` - User interface events and state changes
- `video` - Video playback and download operations
- `networking` - HTTP-level networking details

## Environment Configuration

**Required Environment Variables:**
- `OPENAI_API_KEY` - OpenAI API key for authentication (required at runtime)

The application validates the presence of OPENAI_API_KEY on VideoAPIService initialization and provides clear error messages if missing.

## State Management

- Published properties with @Published for reactive UI updates
- @StateObject for view-owned view models
- @EnvironmentObject for shared coordinators
- Async/await for asynchronous operations
- Task cancellation for polling cleanup

## Error Handling Strategy

1. **Typed Errors**: VideoAPIError enum with specific cases (missingAPIKey, invalidURL, httpError, etc.)
2. **User-Friendly Messages**: LocalizedError conformance for clear error descriptions
3. **Comprehensive Logging**: All errors logged with context via unified logging
4. **UI Feedback**: Error messages displayed inline with appropriate visual indicators
5. **Decoding Diagnostics**: Raw JSON logged on decode failures for debugging

## Development Guidelines

### Code Standards
- Always build after making changes to verify compilation
- Follow SwiftUI best practices for state management
- Use async/await for all API calls (no completion handlers)
- Implement proper error handling with typed errors
- Use @MainActor isolation for view models and UI-related classes
- Leverage Swift's strong type system and optionals

### Testing
- Validate API integration with proper error cases
- Test state transitions in view models
- Verify UI updates with different data states
- Check edge cases (network failures, missing data, etc.)

### Logging
- Use appropriate log levels (debug, info, warning, error)
- Include relevant context in log messages
- Log state transitions and important events
- Use subsystem-specific loggers for clarity

### API Documentation
- IMPORTANT: Do not modify `/internal_docs/openai_video_api_sora2.md` - this is our only reference copy of the Sora-2 API documentation which is not easily available online.
- Refer to this file for API contract details, endpoint specifications, and response formats

## Known Limitations

- Videos are downloaded to temporary directory (not persisted between app launches)
- No local video storage or caching mechanism
- Polling interval fixed at 2 seconds (not configurable)
- No support for video deletion via UI (API endpoint available but not implemented)
- No support for video remixing features (API supports but not yet implemented)

## Future Enhancement Opportunities

- Persistent local video storage with cache management
- Configurable polling intervals
- Delete video functionality in library view
- Video prompt history and favorites
- Batch video generation
- Video remixing from existing videos
- Advanced filtering and sorting in library
- Export video with metadata
