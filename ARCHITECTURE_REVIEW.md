# SoraPlanner - Architectural Review

**Review Date:** October 10, 2025
**Reviewer:** SwiftUI Architecture Expert (Claude Code)
**Application:** SoraPlanner - macOS Video Generation App using OpenAI Sora API

---

## Executive Summary

SoraPlanner demonstrates a **solid architectural foundation** with good separation of concerns, proper use of Swift concurrency, and clean SwiftUI patterns. However, several critical issues around service initialization, state management, and threading need immediate attention before the application scales further.

**Overall Assessment:** Good foundation with critical flaws that will cause problems as the app grows.

**Key Strengths:**
- Excellent use of Swift async/await throughout
- Clean MVVM separation
- Comprehensive logging infrastructure
- Secure credential storage via Keychain
- Well-structured models and API integration

**Critical Weaknesses:**
- Service layer lacks dependency injection
- Threading model misapplied to services
- State management issues in complex views
- Missing error recovery and retry mechanisms
- No caching or offline support

---

## Table of Contents

1. [Critical Issues](#1-critical-issues)
2. [High Priority Issues](#2-high-priority-issues)
3. [Medium Priority Issues](#3-medium-priority-issues)
4. [Low Priority Improvements](#4-low-priority-improvements)
5. [Security Considerations](#5-security-considerations)
6. [Performance Concerns](#6-performance-concerns)
7. [Code Organization](#7-code-organization)
8. [Missing Features](#8-missing-features)
9. [Implementation Roadmap](#9-implementation-roadmap)
10. [Positive Aspects](#10-positive-aspects)

---

## 1. CRITICAL Issues

### 1.1 Service Layer Initialization Anti-Pattern

**Severity:** 🔴 CRITICAL
**Impact:** Testability, Maintainability, Reliability
**Effort:** High (2-3 days)

#### Problem

**Affected Files:**
- `SoraPlanner/ViewModels/VideoGenerationViewModel.swift:72-78`
- `SoraPlanner/ViewModels/VideoLibraryViewModel.swift:26-34`
- `SoraPlanner/ViewModels/VideoPlayerCoordinator.swift:25-33`
- `SoraPlanner/Services/VideoAPIService.swift:42-57`

Each ViewModel creates its own `VideoAPIService` instance in its initializer, catching errors and storing error state:

```swift
// Current (WRONG):
init(initialPrompt: String? = nil) {
    do {
        self.service = try VideoAPIService()
    } catch {
        SoraPlannerLoggers.ui.error("Failed to initialize API service: \(error)")
        self.errorMessage = error.localizedDescription
    }
}
```

#### Why This Is Wrong

1. **Violates Dependency Injection Principle** - Services should be injected, not created internally
2. **Creates Multiple Service Instances** - 3+ separate instances, each fetching API key independently
3. **State Fragmentation** - Each ViewModel can fail initialization independently, leading to inconsistent app state
4. **Broken Initialization Contract** - ViewModels can exist in a broken state (nil service)
5. **Retry Mechanism Duplication** - Each ViewModel has its own `retryAPIServiceInitialization()` method
6. **Impossible to Test** - Cannot inject mock services for unit testing

#### Recommended Solution

**Step 1: Create App Dependencies Container**

```swift
// SoraPlanner/AppDependencies.swift
import SwiftUI

@MainActor
class AppDependencies: ObservableObject {
    @Published private(set) var apiService: VideoAPIService?
    @Published private(set) var initializationError: String?
    @Published private(set) var isInitialized: Bool = false

    init() {
        initializeService()
    }

    func initializeService() {
        do {
            apiService = try VideoAPIService()
            initializationError = nil
            isInitialized = true
            SoraPlannerLoggers.api.info("API service initialized successfully")
        } catch {
            apiService = nil
            initializationError = error.localizedDescription
            isInitialized = false
            SoraPlannerLoggers.api.error("Failed to initialize API service: \(error)")
        }
    }

    func reinitialize() {
        initializeService()
    }
}
```

**Step 2: Inject in App Entry Point**

```swift
// SoraPlanner/SoraPlannerApp.swift
@main
struct SoraPlannerApp: App {
    @StateObject private var dependencies = AppDependencies()
    @StateObject private var playerCoordinator = VideoPlayerCoordinator()

    var body: some Scene {
        WindowGroup {
            if dependencies.isInitialized, let apiService = dependencies.apiService {
                ContentView()
                    .environmentObject(dependencies)
                    .environmentObject(playerCoordinator)
            } else {
                InitializationErrorView(
                    error: dependencies.initializationError,
                    onRetry: { dependencies.reinitialize() }
                )
            }
        }
    }
}
```

**Step 3: Update ViewModels to Accept Injection**

```swift
// SoraPlanner/ViewModels/VideoGenerationViewModel.swift
@MainActor
class VideoGenerationViewModel: ObservableObject {
    private let service: VideoAPIService  // No longer optional!

    // Dependency injection via initializer
    init(service: VideoAPIService, initialPrompt: String? = nil) {
        self.service = service
        if let prompt = initialPrompt {
            self.prompt = prompt
        }
        SoraPlannerLoggers.ui.info("VideoGenerationViewModel initialized")
    }

    // Remove retryAPIServiceInitialization() - no longer needed
}
```

**Step 4: Update View Instantiation**

```swift
// SoraPlanner/Views/PromptLibraryView.swift
.sheet(item: $generationRequest) { request in
    if let apiService = dependencies.apiService {
        VideoGenerationView(
            apiService: apiService,
            initialPrompt: request.prompt,
            onGenerationSuccess: { loadVideos() }
        )
        .environmentObject(playerCoordinator)
    }
}
```

#### Benefits

- ✅ Single source of truth for API service
- ✅ Centralized error handling
- ✅ Easy to test with mock services
- ✅ Clear initialization contract
- ✅ Eliminates state fragmentation
- ✅ Reduces code duplication

---

### 1.2 @MainActor on Service Layer

**Severity:** 🔴 CRITICAL
**Impact:** Performance, Architecture
**Effort:** Medium (1 day)

#### Problem

**Affected File:** `SoraPlanner/Services/VideoAPIService.swift:37`

```swift
@MainActor  // ❌ WRONG - Services should NOT be on MainActor
class VideoAPIService {
    func createVideo(...) async throws -> VideoJob {
        // Network operations forced onto main thread!
    }
}
```

#### Why This Is Wrong

1. **Forces Network Operations onto Main Thread** - Can cause UI jank and freezing
2. **Violates Separation of Concerns** - Service layer shouldn't know about UI threading
3. **URLSession Already Thread-Safe** - Built-in concurrency handling
4. **Performance Degradation** - Unnecessary thread hopping
5. **Architectural Violation** - Only UI layer should be MainActor-isolated

#### Recommended Solution

**Remove @MainActor from Service**

```swift
// SoraPlanner/Services/VideoAPIService.swift
// Remove @MainActor completely
class VideoAPIService {
    private let baseURL = "https://api.openai.com/v1/videos"
    private let apiKey: String

    init() throws {
        // API key retrieval (not MainActor-dependent)
        if let key = KeychainService.shared.getAPIKey() {
            self.apiKey = key
        } else if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.apiKey = envKey
        } else {
            throw VideoAPIError.missingAPIKey
        }
    }

    // All async methods naturally run on background threads
    func createVideo(
        prompt: String,
        model: String = "sora-2",
        seconds: String? = nil,
        size: String? = nil
    ) async throws -> VideoJob {
        // URLSession handles threading automatically
        let (data, response) = try await URLSession.shared.data(for: request)
        // ... rest of implementation
    }
}
```

**Update ViewModels to Handle MainActor Isolation**

```swift
// SoraPlanner/ViewModels/VideoGenerationViewModel.swift
@MainActor  // ViewModel stays on MainActor
class VideoGenerationViewModel: ObservableObject {
    private let service: VideoAPIService  // Service is NOT MainActor

    func generateVideo() async -> Bool {
        // UI updates on MainActor
        isGenerating = true
        errorMessage = nil

        do {
            // API call automatically runs on background thread
            let job = try await service.createVideo(
                prompt: prompt,
                model: model,
                seconds: String(duration),
                size: resolution
            )

            // Back on MainActor for UI updates
            isGenerating = false
            return true
        } catch {
            // Error handling on MainActor
            errorMessage = error.localizedDescription
            isGenerating = false
            return false
        }
    }
}
```

#### Benefits

- ✅ Network operations run on background threads
- ✅ No UI blocking or jank
- ✅ Proper architectural separation
- ✅ Better performance
- ✅ Follows Swift concurrency best practices

---

### 1.3 State Management Issues in PromptRow

**Severity:** 🔴 CRITICAL
**Impact:** Data Integrity, User Experience
**Effort:** Medium (1 day)

#### Problem

**Affected File:** `SoraPlanner/Views/PromptLibraryView.swift:118`

```swift
struct PromptRow: View {
    let prompt: Prompt
    @ObservedObject var viewModel: PromptLibraryViewModel
    let onGenerate: () -> Void

    // ❌ WRONG - @State initialized from parameter creates stale state
    @State private var editedPrompt: Prompt
    @State private var showDeleteConfirmation = false

    init(prompt: Prompt, viewModel: PromptLibraryViewModel, onGenerate: @escaping () -> Void) {
        self.prompt = prompt
        self.viewModel = viewModel
        self.onGenerate = onGenerate
        self._editedPrompt = State(initialValue: prompt)  // Only runs once!
    }
}
```

#### Why This Is Wrong

When the parent's `prompt` changes, SwiftUI doesn't automatically update `editedPrompt` because `@State` is only initialized once during view creation. This creates:

1. **Stale UI State** - Edited values don't reflect parent updates
2. **Data Loss Risk** - Changes can be overwritten
3. **Confusing Behavior** - UI shows outdated information
4. **Implicit View Identity** - Relies on SwiftUI's view identity system

#### Recommended Solution

**Option 1: Use @Binding (Best for Edit-in-Place)**

```swift
struct PromptRow: View {
    @Binding var prompt: Prompt
    let onGenerate: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Direct binding - no intermediate state
            TextField("Prompt Title", text: $prompt.title)
                .textFieldStyle(.plain)
                .font(.headline)

            TextEditor(text: $prompt.text)
                .frame(minHeight: 100, maxHeight: 200)

            // ... rest of view
        }
        .onChange(of: prompt) { oldValue, newValue in
            // Parent handles persistence automatically
        }
    }
}

// In PromptLibraryView:
ForEach($viewModel.prompts) { $prompt in
    PromptRow(
        prompt: $prompt,
        onGenerate: { generateRequest = .init(prompt: prompt.text) },
        onDelete: { viewModel.deletePrompt(prompt) }
    )
}
```

**Option 2: Computed Bindings (Alternative)**

```swift
struct PromptRow: View {
    let prompt: Prompt
    @ObservedObject var viewModel: PromptLibraryViewModel
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Prompt Title", text: Binding(
                get: { prompt.title },
                set: { newValue in
                    var updated = prompt
                    updated.title = newValue
                    viewModel.updatePrompt(updated)
                }
            ))

            TextEditor(text: Binding(
                get: { prompt.text },
                set: { newValue in
                    var updated = prompt
                    updated.text = newValue
                    viewModel.updatePrompt(updated)
                }
            ))
        }
    }
}
```

#### Benefits

- ✅ No stale state
- ✅ Single source of truth
- ✅ Predictable behavior
- ✅ Automatic persistence
- ✅ Simpler code

---

### 1.4 Missing Task Cancellation

**Severity:** 🔴 CRITICAL
**Impact:** Data Races, Memory Leaks
**Effort:** Low (4 hours)

#### Problem

**Affected Files:**
- `SoraPlanner/ViewModels/VideoPlayerCoordinator.swift:16-19`
- `SoraPlanner/Views/VideoPlayerView.swift:105-110`
- `SoraPlanner/Views/ConfigurationView.swift:204-206`

Video playback state managed in multiple places without task cancellation creates race conditions.

**Scenario:** User opens video A, quickly closes it, then opens video B. Both download tasks might still be running, leading to:
- Race conditions on state updates
- Memory leaks from uncancelled tasks
- Wrong video displayed
- Crashes from concurrent state mutations

#### Current Code

```swift
// VideoPlayerCoordinator.swift
@MainActor
class VideoPlayerCoordinator: ObservableObject {
    @Published var currentVideo: VideoJob?
    @Published var videoURL: URL?
    @Published var isLoading = false

    func play(_ video: VideoJob) {
        currentVideo = video
        isLoading = true

        Task {
            // ❌ No cancellation - multiple tasks can run concurrently!
            do {
                videoURL = try await service.downloadVideo(videoId: video.id)
                isLoading = false
            } catch {
                isLoading = false
            }
        }
    }
}
```

#### Recommended Solution

```swift
// SoraPlanner/ViewModels/VideoPlayerCoordinator.swift
@MainActor
class VideoPlayerCoordinator: ObservableObject {
    @Published var currentVideo: VideoJob?
    @Published var videoURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var downloadTask: Task<Void, Never>?

    func play(_ video: VideoJob) {
        // Cancel any existing download
        downloadTask?.cancel()

        // Reset state
        currentVideo = video
        videoURL = nil
        isLoading = true
        errorMessage = nil

        // Create new task with cancellation support
        downloadTask = Task { @MainActor in
            do {
                // Check cancellation before starting
                try Task.checkCancellation()

                let url = try await service.downloadVideo(videoId: video.id)

                // Check cancellation before updating state
                try Task.checkCancellation()

                videoURL = url
                isLoading = false
                SoraPlannerLoggers.video.info("Video loaded: \(video.id)")
            } catch is CancellationError {
                // Clean cancellation - don't update state
                SoraPlannerLoggers.video.debug("Video download cancelled: \(video.id)")
            } catch {
                // Only update error state if not cancelled
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    SoraPlannerLoggers.video.error("Failed to load video: \(error)")
                }
            }
        }
    }

    func dismiss() {
        // Cancel download task
        downloadTask?.cancel()
        downloadTask = nil

        // Clear state
        currentVideo = nil
        videoURL = nil
        isLoading = false
        errorMessage = nil
    }
}
```

**Fix ConfigurationView Timing Issues**

```swift
// SoraPlanner/Views/ConfigurationView.swift
@State private var successTask: Task<Void, Never>?

private func showSuccess() {
    showingSuccess = true
    showingError = false

    // Cancel previous task
    successTask?.cancel()

    // Use Task.sleep for cancellable timing
    successTask = Task {
        do {
            try await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                showingSuccess = false
            }
        } catch {
            // Task was cancelled - do nothing
        }
    }
}

var body: some View {
    // ... view content
    .onDisappear {
        successTask?.cancel()
    }
}
```

#### Benefits

- ✅ No race conditions
- ✅ Proper resource cleanup
- ✅ Predictable state transitions
- ✅ No memory leaks
- ✅ Better error handling

---

## 2. HIGH Priority Issues

### 2.1 No Protocol Abstractions for Services

**Severity:** 🟡 HIGH
**Impact:** Testability
**Effort:** Medium (1 day)

#### Problem

`VideoAPIService` is a concrete class with no protocol abstraction, making unit testing impossible.

**Current Issues:**
- Cannot inject mock services for testing
- ViewModels tightly coupled to implementation
- Cannot swap implementations (e.g., local vs. remote)
- Makes TDD (Test-Driven Development) impossible

#### Recommended Solution

```swift
// SoraPlanner/Services/VideoAPIServiceProtocol.swift
protocol VideoAPIServiceProtocol {
    func createVideo(prompt: String, model: String, seconds: String?, size: String?) async throws -> VideoJob
    func getVideoStatus(videoId: String) async throws -> VideoJob
    func downloadVideo(videoId: String) async throws -> URL
    func listVideos(limit: Int) async throws -> [VideoJob]
}

// Conform existing service
extension VideoAPIService: VideoAPIServiceProtocol {}

// Create mock for testing
class MockVideoAPIService: VideoAPIServiceProtocol {
    var createVideoResult: Result<VideoJob, Error> = .failure(VideoAPIError.missingAPIKey)
    var getVideoStatusResult: Result<VideoJob, Error> = .failure(VideoAPIError.missingAPIKey)

    func createVideo(prompt: String, model: String, seconds: String?, size: String?) async throws -> VideoJob {
        try createVideoResult.get()
    }

    func getVideoStatus(videoId: String) async throws -> VideoJob {
        try getVideoStatusResult.get()
    }

    // ... implement other methods
}

// Update ViewModels to use protocol
@MainActor
class VideoGenerationViewModel: ObservableObject {
    private let service: VideoAPIServiceProtocol  // Protocol, not concrete type

    init(service: VideoAPIServiceProtocol, initialPrompt: String? = nil) {
        self.service = service
    }
}
```

**Example Test:**

```swift
// SoraPlannerTests/VideoGenerationViewModelTests.swift
@MainActor
class VideoGenerationViewModelTests: XCTestCase {
    func testSuccessfulVideoGeneration() async {
        // Arrange
        let mockService = MockVideoAPIService()
        mockService.createVideoResult = .success(VideoJob(
            id: "test-123",
            status: .queued,
            createdAt: Int(Date().timeIntervalSince1970)
        ))

        let viewModel = VideoGenerationViewModel(
            service: mockService,
            initialPrompt: "Test prompt"
        )

        // Act
        let success = await viewModel.generateVideo()

        // Assert
        XCTAssertTrue(success)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isGenerating)
    }
}
```

---

### 2.2 Missing Error Recovery and Retry Logic

**Severity:** 🟡 HIGH
**Impact:** Reliability, User Experience
**Effort:** Medium (1-2 days)

#### Problem

No retry logic for transient network failures. Single temporary failure = complete user-facing error.

**Missing Features:**
- Network reachability detection
- Automatic retry with exponential backoff
- User-friendly error messages
- Offline mode support

#### Recommended Solution

**Step 1: Network Monitor**

```swift
// SoraPlanner/Services/NetworkMonitor.swift
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
```

**Step 2: Retry Logic in Service**

```swift
// SoraPlanner/Services/VideoAPIService.swift
extension VideoAPIService {
    func createVideoWithRetry(
        prompt: String,
        model: String = "sora-2",
        seconds: String? = nil,
        size: String? = nil,
        maxRetries: Int = 3
    ) async throws -> VideoJob {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let job = try await createVideo(
                    prompt: prompt,
                    model: model,
                    seconds: seconds,
                    size: size
                )
                return job
            } catch let error as VideoAPIError where error.isRetryable {
                lastError = error

                // Exponential backoff: 1s, 2s, 4s, max 10s
                let delay = min(pow(2.0, Double(attempt - 1)), 10.0)
                SoraPlannerLoggers.api.warning("Request failed (attempt \(attempt)/\(maxRetries)), retrying in \(delay)s: \(error)")

                try await Task.sleep(for: .seconds(delay))
            } catch {
                // Non-retryable error - fail immediately
                throw error
            }
        }

        throw lastError ?? VideoAPIError.networkError(
            NSError(domain: "VideoAPIService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Maximum retry attempts exceeded"
            ])
        )
    }
}

// Extend error type with retry logic
extension VideoAPIError {
    var isRetryable: Bool {
        switch self {
        case .networkError:
            return true
        case .httpError(let code, _):
            // Retry on server errors and rate limits
            return code >= 500 || code == 429 || code == 408
        case .decodingError, .missingAPIKey, .invalidURL:
            return false
        }
    }
}
```

**Step 3: User-Facing Retry UI**

```swift
// In ViewModels
@Published var isRetrying = false
@Published var retryCount = 0

func generateVideo() async -> Bool {
    isGenerating = true
    errorMessage = nil
    retryCount = 0

    do {
        let job = try await service.createVideoWithRetry(...)
        // Success handling
        return true
    } catch {
        errorMessage = error.localizedDescription
        isGenerating = false
        return false
    }
}
```

---

### 2.3 Memory Management for Large Video Files

**Severity:** 🟡 HIGH
**Impact:** Performance, Memory Usage
**Effort:** Low (4 hours)

#### Problem

**Affected File:** `SoraPlanner/Services/VideoAPIService.swift:194`

```swift
func downloadVideo(videoId: String) async throws -> URL {
    // ❌ Loads entire video into memory before writing
    let (data, response) = try await URLSession.shared.data(for: request)
    try data.write(to: videoURL)
}
```

**Impact:**
- 12-second 4K video ≈ 50-100 MB in memory
- Multiple videos = hundreds of MB
- Potential crashes on memory-constrained systems
- Poor performance during downloads

#### Recommended Solution

```swift
// SoraPlanner/Services/VideoAPIService.swift
func downloadVideo(videoId: String) async throws -> URL {
    guard let url = URL(string: "\(baseURL)/\(videoId)/content") else {
        throw VideoAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // ✅ Use download task - streams directly to disk
    let (localURL, response) = try await URLSession.shared.download(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw VideoAPIError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
        throw VideoAPIError.httpError(code: httpResponse.statusCode, message: "Download failed")
    }

    // Move to permanent location
    let tempDirectory = FileManager.default.temporaryDirectory
    let destinationURL = tempDirectory
        .appendingPathComponent("SoraPlanner")
        .appendingPathComponent("\(videoId).mp4")

    // Create directory if needed
    try FileManager.default.createDirectory(
        at: destinationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    // Remove existing file if present
    try? FileManager.default.removeItem(at: destinationURL)

    // Move downloaded file
    try FileManager.default.moveItem(at: localURL, to: destinationURL)

    SoraPlannerLoggers.video.info("Video downloaded to: \(destinationURL.path)")
    return destinationURL
}
```

#### Benefits

- ✅ Minimal memory usage (streaming to disk)
- ✅ Better performance
- ✅ No memory pressure
- ✅ Supports larger videos

---

### 2.4 Excessive Logging in Production

**Severity:** 🟡 HIGH
**Impact:** Performance, Privacy, Debugging
**Effort:** Low (4 hours)

#### Problem

**Affected Files:** Throughout codebase, especially:
- `SoraPlanner/Services/VideoAPIService.swift:137-165`
- `SoraPlanner/ViewModels/VideoLibraryViewModel.swift:72-103`

```swift
// ❌ Logs raw JSON and user prompts in PRODUCTION
SoraPlannerLoggers.api.info("Creating video job with model: \(model), size: \(size ?? "default"), prompt: \(prompt.prefix(50))...")

// ❌ Logs every queued and failed video with raw JSON
SoraPlannerLoggers.api.info("Queued for \(queuedDuration)s: \(video.id)")
if let rawJSON = try? String(data: data, encoding: .utf8) {
    SoraPlannerLoggers.api.debug("Raw JSON for queued video: \(rawJSON)")
}
```

**Issues:**
- Performance overhead in hot paths
- Privacy concern - user prompts logged
- Noise makes debugging harder
- Large log files

#### Recommended Solution

```swift
// SoraPlanner/Services/VideoAPIService.swift
func createVideo(...) async throws -> VideoJob {
    // Use appropriate log levels and conditional compilation
    #if DEBUG
    SoraPlannerLoggers.api.debug("Creating video with model: \(model), size: \(size ?? "default")")
    SoraPlannerLoggers.api.debug("Prompt preview: \(prompt.prefix(50))...")
    #endif

    // Production: only log minimal info
    SoraPlannerLoggers.api.info("Creating video job with model: \(model)")

    // ... implementation
}

// Only log errors and warnings in production
func handleVideoStatus(_ video: VideoJob, rawJSON: String? = nil) {
    switch video.status {
    case .failed:
        SoraPlannerLoggers.api.error("Video generation failed: \(video.id)")
        if let error = video.error {
            SoraPlannerLoggers.api.error("Error: \(error.message)")
        }

        #if DEBUG
        if let json = rawJSON {
            SoraPlannerLoggers.api.debug("Raw response: \(json)")
        }
        #endif

    case .queued where video.queuedDuration > 300:
        // Only log unusually long queues
        SoraPlannerLoggers.api.warning("Video queued for \(video.queuedDuration)s: \(video.id)")

    default:
        // Don't log normal operations in production
        #if DEBUG
        SoraPlannerLoggers.api.debug("Video status: \(video.status) for \(video.id)")
        #endif
    }
}
```

---

### 2.5 No Pagination Support

**Severity:** 🟡 HIGH
**Impact:** Scalability
**Effort:** Medium (1 day)

#### Problem

**Affected File:** `SoraPlanner/Services/VideoAPIService.swift:262`

```swift
// ❌ Hardcoded limit, no pagination
func listVideos(limit: Int = 100) async throws -> [VideoJob] {
    // Returns max 100 videos, older videos invisible
}
```

**Impact:**
- Users with >100 videos can't see all their content
- No "load more" functionality
- Poor UX as library grows

#### Recommended Solution

```swift
// SoraPlanner/Models/VideoJob.swift
struct VideoListResponse: Codable {
    let videos: [VideoJob]
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case videos = "data"
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

// SoraPlanner/Services/VideoAPIService.swift
func listVideos(limit: Int = 100, after: String? = nil) async throws -> VideoListResponse {
    guard let baseURL = URL(string: baseURL) else {
        throw VideoAPIError.invalidURL
    }

    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    var queryItems = [URLQueryItem(name: "limit", value: String(limit))]

    if let after = after {
        queryItems.append(URLQueryItem(name: "after", value: after))
    }

    components?.queryItems = queryItems

    guard let url = components?.url else {
        throw VideoAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    // ... error handling

    let listResponse = try JSONDecoder().decode(VideoListResponse.self, from: data)
    return listResponse
}

// SoraPlanner/ViewModels/VideoLibraryViewModel.swift
@MainActor
class VideoLibraryViewModel: ObservableObject {
    @Published var videos: [VideoJob] = []
    @Published var hasMore = false
    @Published var isLoadingMore = false
    private var nextCursor: String?

    func loadVideos() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await service.listVideos(limit: 50)
            videos = response.videos
            hasMore = response.hasMore
            nextCursor = response.nextCursor
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func loadMoreVideos() async {
        guard hasMore, !isLoadingMore, let cursor = nextCursor else { return }

        isLoadingMore = true

        do {
            let response = try await service.listVideos(limit: 50, after: cursor)
            videos.append(contentsOf: response.videos)
            hasMore = response.hasMore
            nextCursor = response.nextCursor
            isLoadingMore = false
        } catch {
            // Don't overwrite main error message
            SoraPlannerLoggers.api.error("Failed to load more videos: \(error)")
            isLoadingMore = false
        }
    }
}
```

**UI Implementation:**

```swift
// SoraPlanner/Views/VideoLibraryView.swift
ScrollView {
    LazyVStack(spacing: 12) {
        ForEach(viewModel.videos) { video in
            VideoLibraryRow(video: video, viewModel: viewModel)
                .onAppear {
                    // Load more when approaching end
                    if video == viewModel.videos.last {
                        Task {
                            await viewModel.loadMoreVideos()
                        }
                    }
                }
        }

        if viewModel.isLoadingMore {
            ProgressView()
                .padding()
        }
    }
}
```

---

## 3. MEDIUM Priority Issues

### 3.1 No Caching or Local Storage Strategy

**Severity:** 🟠 MEDIUM
**Impact:** User Experience, Performance
**Effort:** High (3-5 days)

#### Problem

Every app launch requires:
- Re-fetching all videos from API
- Re-downloading videos for playback
- No offline capability
- Temporary directory cleared on relaunch

#### Recommended Solution

Implement SwiftData (or Core Data) caching layer:

```swift
// SoraPlanner/Models/CachedVideoJob.swift
import SwiftData

@Model
class CachedVideoJob {
    @Attribute(.unique) var id: String
    var status: String
    var createdAt: Int
    var completedAt: Int?
    var expiresAt: Int?
    var prompt: String
    var duration: Int
    var model: String
    var resolution: String?
    var quality: String?
    var localFileURL: URL?
    var lastUpdated: Date
    var errorMessage: String?

    init(from videoJob: VideoJob) {
        self.id = videoJob.id
        self.status = videoJob.status.rawValue
        self.createdAt = videoJob.createdAt
        // ... map other properties
        self.lastUpdated = Date()
    }

    func toVideoJob() -> VideoJob {
        VideoJob(
            id: id,
            status: VideoStatus(rawValue: status) ?? .queued,
            createdAt: createdAt,
            // ... map back
        )
    }
}

// SoraPlanner/Services/VideoCacheService.swift
@MainActor
class VideoCacheService {
    private let modelContext: ModelContext

    func cacheVideo(_ video: VideoJob, localURL: URL? = nil) {
        let cached = CachedVideoJob(from: video)
        cached.localFileURL = localURL
        modelContext.insert(cached)
        try? modelContext.save()
    }

    func getCachedVideos() -> [VideoJob] {
        let descriptor = FetchDescriptor<CachedVideoJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let cached = try? modelContext.fetch(descriptor)
        return cached?.map { $0.toVideoJob() } ?? []
    }

    func getLocalVideoURL(for videoId: String) -> URL? {
        let predicate = #Predicate<CachedVideoJob> { $0.id == videoId }
        let descriptor = FetchDescriptor(predicate: predicate)
        let cached = try? modelContext.fetch(descriptor).first
        return cached?.localFileURL
    }
}
```

---

### 3.2 No Background Refresh or Polling

**Severity:** 🟠 MEDIUM
**Impact:** User Experience
**Effort:** Medium (1 day)

#### Problem

Video status only updates on manual refresh. User must repeatedly pull-to-refresh to check generation progress.

#### Recommended Solution

```swift
// SoraPlanner/ViewModels/VideoLibraryViewModel.swift
@MainActor
class VideoLibraryViewModel: ObservableObject {
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 5.0

    func startPollingForActiveVideos() {
        // Cancel existing polling
        pollingTask?.cancel()

        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                // Check if we have any in-progress videos
                let activeVideos = videos.filter {
                    $0.status == .inProgress || $0.status == .queued
                }

                if activeVideos.isEmpty {
                    // No active videos, stop polling
                    SoraPlannerLoggers.ui.debug("No active videos, stopping poll")
                    break
                }

                // Wait before next poll
                try? await Task.sleep(for: .seconds(pollingInterval))

                // Check cancellation after sleep
                if Task.isCancelled { break }

                // Refresh videos
                await loadVideos()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func loadVideos() async {
        // ... existing implementation

        // After loading, check if we should start polling
        let hasActiveVideos = videos.contains {
            $0.status == .inProgress || $0.status == .queued
        }

        if hasActiveVideos {
            startPollingForActiveVideos()
        } else {
            stopPolling()
        }
    }
}

// In view:
.onAppear {
    Task {
        await viewModel.loadVideos()
    }
}
.onDisappear {
    viewModel.stopPolling()
}
```

---

### 3.3 Large View Decomposition

**Severity:** 🟠 MEDIUM
**Impact:** Maintainability
**Effort:** Medium (1 day)

#### Problem

**Affected File:** `SoraPlanner/Views/VideoLibraryView.swift:107-299`

`VideoLibraryRow` is 192 lines handling multiple responsibilities:
- Display
- Deletion
- Saving to Photos
- Error handling

#### Recommended Solution

```swift
// Break into smaller, focused components

struct VideoLibraryRow: View {
    let video: VideoJob
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VideoRowHeader(video: video, viewModel: viewModel)
            VideoRowDetails(video: video)
            VideoRowMetadata(video: video, viewModel: viewModel)
        }
        .videoRowStyling(status: video.status)
    }
}

struct VideoRowHeader: View {
    let video: VideoJob
    @ObservedObject var viewModel: VideoLibraryViewModel

    var body: some View {
        HStack {
            StatusBadge(status: video.status, progress: video.progress)
            Spacer()
            if video.status == .completed {
                VideoRowActions(video: video, viewModel: viewModel)
            }
        }
    }
}

struct VideoRowDetails: View {
    let video: VideoJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ID: \(video.id)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let output = video.output {
                VideoOutputInfo(output: output)
            }
        }
    }
}

struct StatusBadge: View {
    let status: VideoStatus
    let progress: Int?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.displayColor)
                .frame(width: 8, height: 8)
            Text(status.displayText(progress: progress))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// Reusable modifier
extension View {
    func videoRowStyling(status: VideoStatus) -> some View {
        self
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(status.borderColor, lineWidth: status.borderWidth)
            )
    }
}

// Move presentation logic to extensions
extension VideoStatus {
    var displayColor: Color {
        switch self {
        case .queued: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    func displayText(progress: Int?) -> String {
        switch self {
        case .queued: return "Queued"
        case .inProgress:
            if let progress = progress {
                return "Processing: \(progress)%"
            }
            return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var borderColor: Color {
        self == .failed ? .red.opacity(0.5) : .clear
    }

    var borderWidth: CGFloat {
        self == .failed ? 1 : 0
    }
}
```

---

### 3.4 Hardcoded Magic Numbers

**Severity:** 🟠 MEDIUM
**Impact:** Maintainability
**Effort:** Low (2 hours)

#### Problem

Magic numbers scattered throughout:
- `maxCharacters = 2000` in PromptLibraryView
- Prices `0.10`, `0.30`, `0.50` in VideoGenerationViewModel
- Polling intervals, timeouts, etc.

#### Recommended Solution

```swift
// SoraPlanner/AppConstants.swift
enum AppConstants {
    enum Prompts {
        static let maxCharacterCount = 2000
        static let userDefaultsKey = "saved_prompts"
    }

    enum Pricing {
        static let sora2PerSecond: Double = 0.10
        static let sora2ProStandardPerSecond: Double = 0.30
        static let sora2ProHighResPerSecond: Double = 0.50
    }

    enum Video {
        static let defaultDownloadDirectory = "SoraPlanner/Videos"
        static let pollingInterval: TimeInterval = 5.0
        static let maxDownloadRetries = 3
        static let downloadTimeout: TimeInterval = 60.0
    }

    enum API {
        static let baseURL = "https://api.openai.com/v1/videos"
        static let defaultListLimit = 100
        static let requestTimeout: TimeInterval = 30.0
    }

    enum UI {
        static let successMessageDuration: TimeInterval = 3.0
        static let minWindowWidth: CGFloat = 600
        static let minWindowHeight: CGFloat = 600
    }
}

// Usage:
var pricePerSecond: Double {
    if model == "sora-2" {
        return AppConstants.Pricing.sora2PerSecond
    } else if isHighResProResolution {
        return AppConstants.Pricing.sora2ProHighResPerSecond
    } else {
        return AppConstants.Pricing.sora2ProStandardPerSecond
    }
}
```

---

### 3.5 Incomplete Logging Strategy

**Severity:** 🟠 MEDIUM
**Impact:** Debugging, Deployment
**Effort:** Low (1 hour)

#### Problem

**Affected File:** `SoraPlanner/Utilities/Logging.swift:18`

```swift
// ❌ Hardcoded subsystem identifier
private static let subsystem = "com.yourorg.SoraPlanner"
```

Should use bundle identifier for proper app identification.

#### Recommended Solution

```swift
// SoraPlanner/Utilities/Logging.swift
import OSLog

struct SoraPlannerLoggers {
    // Use bundle identifier
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.soraplanner.app"

    static let api = Logger(subsystem: subsystem, category: "api")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let video = Logger(subsystem: subsystem, category: "video")
    static let networking = Logger(subsystem: subsystem, category: "networking")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let performance = Logger(subsystem: subsystem, category: "performance")
}

// Add performance logging
extension SoraPlannerLoggers {
    static func logPerformance<T>(
        _ operation: String,
        category: Logger = .performance,
        _ block: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            category.debug("\(operation) took \(String(format: "%.3f", duration))s")
        }
        return try block()
    }
}
```

---

### 3.6 ViewModels Contain UI-Specific Logic

**Severity:** 🟠 MEDIUM
**Impact:** Testability, Architecture
**Effort:** Medium (1 day)

#### Problem

**Affected File:** `SoraPlanner/ViewModels/VideoLibraryViewModel.swift:214-252`

ViewModels return color strings and UI formatting:

```swift
// ❌ ViewModel shouldn't know about colors
func statusColor(for video: VideoJob) -> String {
    switch video.status {
    case .queued: return "blue"
    case .inProgress: return "orange"
    case .completed: return "green"
    case .failed: return "red"
    }
}
```

#### Recommended Solution

Move presentation logic to View layer:

```swift
// Remove from ViewModel completely

// Add to Model extension or View
extension VideoStatus {
    var displayColor: Color {
        switch self {
        case .queued: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    var icon: String {
        switch self {
        case .queued: return "clock"
        case .inProgress: return "hourglass"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

// In view:
Circle()
    .fill(video.status.displayColor)

Image(systemName: video.status.icon)
    .foregroundColor(video.status.displayColor)
```

---

### 3.7 Manual Dismiss Timing Issues

**Severity:** 🟠 MEDIUM
**Impact:** User Experience
**Effort:** Low (2 hours)

#### Problem

**Affected File:** `SoraPlanner/Views/VideoGenerationView.swift:177-185`

```swift
Button(action: {
    Task {
        let success = await viewModel.generateVideo()
        if success {
            dismiss()  // ⚠️ Dismiss immediately
            onGenerationSuccess()  // Then call callback
        }
    }
})
```

Callback is called AFTER dismiss, which might cause success message to appear on wrong view or get lost.

#### Recommended Solution

**Option 1: Pass Dismiss to ViewModel**

```swift
func generateVideo(onSuccess: @escaping () -> Void) async -> Bool {
    isGenerating = true
    errorMessage = nil

    do {
        let job = try await service.createVideo(...)

        // Call success callback BEFORE resetting state
        onSuccess()

        // Reset state
        prompt = ""
        duration = 4
        model = "sora-2"
        resolution = "720x1280"
        isGenerating = false

        return true
    } catch {
        errorMessage = error.localizedDescription
        isGenerating = false
        return false
    }
}

// In view:
Button(action: {
    Task {
        let success = await viewModel.generateVideo {
            // Success callback executes before dismiss
            onGenerationSuccess()
        }
        if success {
            dismiss()
        }
    }
})
```

**Option 2: Use @Binding for Success State**

```swift
struct VideoGenerationView: View {
    @Binding var showSuccessMessage: Bool

    Button(action: {
        Task {
            let success = await viewModel.generateVideo()
            if success {
                showSuccessMessage = true
                dismiss()
            }
        }
    })
}

// Parent handles success message display
```

---

### 3.8 Unnecessary EnvironmentObject Passing

**Severity:** 🟠 MEDIUM
**Impact:** Code Cleanliness
**Effort:** Low (30 minutes)

#### Problem

**Affected File:** `SoraPlanner/ContentView.swift:58`

```swift
.sheet(item: $generationRequest) { request in
    VideoGenerationView(...)
        .environmentObject(playerCoordinator)  // ⚠️ Not used in this view
}
```

Creates unnecessary dependency coupling.

#### Recommended Solution

```swift
// Remove unused environment object
.sheet(item: $generationRequest) { request in
    VideoGenerationView(
        initialPrompt: request.prompt,
        onGenerationSuccess: { loadVideos() }
    )
    // Don't pass playerCoordinator if not needed
}
```

---

### 3.9 String-Based Enum Conversion

**Severity:** 🟠 MEDIUM
**Impact:** Type Safety
**Effort:** Low (1 hour)

#### Problem

Converting enums to strings and back:

```swift
// ViewModel returns string
func statusColor(for video: VideoJob) -> String {
    switch video.status {
    case .queued: return "blue"
    // ...
    }
}

// View converts string to Color
private var statusColor: Color {
    switch viewModel.statusColor(for: video) {
    case "blue": return .blue
    // ...
    default: return .gray  // ⚠️ Stringly-typed, error-prone
    }
}
```

#### Recommended Solution

Use type-safe extensions (see 3.6 above).

---

## 4. LOW Priority Improvements

### 4.1 No Undo/Redo for Prompts

**Severity:** 🟢 LOW
**Impact:** User Experience
**Effort:** Medium (1-2 days)

Users can accidentally delete prompts with no recovery. Consider implementing:

```swift
// SoraPlanner/ViewModels/PromptLibraryViewModel.swift
@Published var undoManager = UndoManager()

func deletePrompt(_ prompt: Prompt) {
    let deletedPrompt = prompt
    let deletedIndex = prompts.firstIndex(where: { $0.id == prompt.id })

    prompts.removeAll { $0.id == prompt.id }
    savePrompts()

    // Register undo
    undoManager.registerUndo(withTarget: self) { viewModel in
        if let index = deletedIndex {
            viewModel.prompts.insert(deletedPrompt, at: index)
        } else {
            viewModel.prompts.append(deletedPrompt)
        }
        viewModel.savePrompts()
    }
}
```

---

### 4.2 No Accessibility Considerations

**Severity:** 🟢 LOW
**Impact:** Accessibility
**Effort:** Medium (2-3 days)

Missing:
- VoiceOver labels
- Dynamic Type support
- Keyboard navigation
- High contrast support

#### Recommended Solution

```swift
// Add accessibility labels
Button(action: { deletePrompt() }) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete prompt")
.accessibilityHint("Permanently removes this prompt from your library")

// Support Dynamic Type
Text(prompt.title)
    .font(.headline)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

// Keyboard shortcuts
.keyboardShortcut("n", modifiers: .command)  // New prompt
.keyboardShortcut(.delete, modifiers: .command)  // Delete
```

---

### 4.3 No Analytics or Telemetry

**Severity:** 🟢 LOW
**Impact:** Product Insights
**Effort:** Medium (2-3 days)

Consider adding privacy-respecting analytics:

```swift
// Track usage patterns (anonymized)
enum AnalyticsEvent {
    case videoGenerated(model: String, duration: Int, resolution: String)
    case videoFailed(errorType: String)
    case promptSaved
    case apiKeyConfigured
}

class AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        // Log to analytics service (e.g., TelemetryDeck)
        // Or local analytics for debugging
    }
}
```

---

### 4.4 No Conflict Resolution for iCloud Sync

**Severity:** 🟢 LOW
**Impact:** Future-proofing
**Effort:** High (3-5 days)

If adding iCloud sync in future, need conflict resolution strategy for prompts.

---

## 5. SECURITY Considerations

### 5.1 API Key in Memory

**Severity:** 🟡 INFORMATIONAL
**Impact:** Security
**Effort:** Medium (1-2 days)

Current implementation stores API key as plain string in memory. While better than logging it, consider:

```swift
// More secure approach using secure memory
class SecureString {
    private var data: Data

    init?(_ string: String) {
        guard let data = string.data(using: .utf8) else { return nil }
        self.data = data
    }

    func withUnsafeString<T>(_ body: (String) -> T) -> T {
        let string = String(data: data, encoding: .utf8) ?? ""
        defer {
            // Overwrite memory after use
            var mutableData = data
            mutableData.resetBytes(in: 0..<mutableData.count)
        }
        return body(string)
    }

    deinit {
        // Zero out memory
        data.resetBytes(in: 0..<data.count)
    }
}
```

**Note:** This is advanced security - may be overkill for this app.

---

### 5.2 No Request Signing or Validation

**Severity:** 🟡 INFORMATIONAL
**Impact:** Security
**Effort:** High (3-5 days)

No validation that responses actually come from OpenAI servers (no certificate pinning).

For production apps handling sensitive data, consider:

```swift
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate certificate
        // ... implementation
    }
}
```

**Note:** OpenAI handles this at their end, probably unnecessary for this use case.

---

### 5.3 Keychain Error Handling Lacks User Guidance

**Severity:** 🟠 MEDIUM
**Impact:** User Experience
**Effort:** Low (2 hours)

**Affected File:** `SoraPlanner/Services/KeychainService.swift:44-50`

Current errors are technical and unhelpful:

```swift
guard status == errSecSuccess else {
    logger.error("Failed to save API key to keychain: \(status)")
    throw KeychainError.saveFailed(status: status)  // ⚠️ Just error code
}
```

#### Recommended Solution

```swift
// SoraPlanner/Services/KeychainService.swift
enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case retrieveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return humanReadableMessage(for: status, operation: "save")
        case .retrieveFailed(let status):
            return humanReadableMessage(for: status, operation: "retrieve")
        case .deleteFailed(let status):
            return humanReadableMessage(for: status, operation: "delete")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed(let status), .retrieveFailed(let status), .deleteFailed(let status):
            return recoverySuggestionForStatus(status)
        }
    }

    private func humanReadableMessage(for status: OSStatus, operation: String) -> String {
        switch status {
        case errSecAuthFailed:
            return "Authentication failed. Please ensure your user account has permission to access the keychain."
        case errSecUserCanceled:
            return "Operation cancelled by user."
        case errSecNotAvailable:
            return "Keychain is not available. This may occur if your Mac is locked or FileVault is not enabled."
        case errSecDuplicateItem:
            return "An API key already exists in the keychain."
        case errSecInteractionNotAllowed:
            return "Cannot access keychain while the device is locked."
        case errSecItemNotFound:
            return "No API key found in keychain."
        default:
            return "Failed to \(operation) API key in keychain (error code: \(status))."
        }
    }

    private func recoverySuggestionForStatus(_ status: OSStatus) -> String {
        switch status {
        case errSecAuthFailed:
            return "Check System Settings > Privacy & Security > Keychain Access permissions."
        case errSecNotAvailable:
            return "Ensure your Mac is unlocked and FileVault is enabled in System Settings."
        case errSecDuplicateItem:
            return "Delete the existing API key first, then try again."
        case errSecInteractionNotAllowed:
            return "Unlock your Mac and try again."
        case errSecItemNotFound:
            return "Configure your API key in the Settings tab."
        default:
            return "Please try again or restart the application."
        }
    }
}
```

---

## 6. PERFORMANCE Concerns

### 6.1 Individual Status Checks for Multiple Videos

**Severity:** 🟡 HIGH
**Impact:** Performance
**Effort:** Low (2 hours)

**Affected File:** `SoraPlanner/ViewModels/VideoLibraryViewModel.swift:72-103`

```swift
// ❌ Sequential API calls for each failed video
for video in failedVideos {
    _ = try await service.getVideoStatus(videoId: video.id)
}
for video in longQueuedVideos {
    _ = try await service.getVideoStatus(videoId: video.id)
}
```

**Problem:** 10 failed videos = 10 sequential API calls = slow refresh

#### Recommended Solution

```swift
// Make concurrent API calls with limit
func checkProblematicVideos() async {
    let problematicVideos = videos.filter {
        $0.status == .failed || ($0.status == .queued && $0.queuedDuration > 300)
    }

    guard !problematicVideos.isEmpty else { return }

    // Limit concurrent requests to avoid overwhelming server
    await withTaskGroup(of: Void.self) { group in
        for video in problematicVideos.prefix(5) {
            group.addTask {
                do {
                    let updated = try await self.service.getVideoStatus(videoId: video.id)
                    SoraPlannerLoggers.api.info("Updated status for \(video.id): \(updated.status)")
                } catch {
                    SoraPlannerLoggers.api.error("Failed to fetch status for \(video.id): \(error)")
                }
            }
        }
    }
}
```

**Better:** Remove this entirely - it's redundant logging that serves no user-facing purpose.

---

### 6.2 No View Identity Optimization

**Severity:** 🟠 MEDIUM
**Impact:** Performance
**Effort:** Low (1 hour)

**Affected File:** `SoraPlanner/Views/VideoLibraryView.swift:85-86`

```swift
LazyVStack(spacing: 12) {
    ForEach(viewModel.videos) { video in
        VideoLibraryRow(video: video, viewModel: viewModel)
    }
}
```

#### Recommended Solution

```swift
LazyVStack(spacing: 12) {
    ForEach(viewModel.videos, id: \.id) { video in
        VideoLibraryRow(video: video, viewModel: viewModel)
            .id(video.id)  // Explicit identity
            .equatable()   // Prevent unnecessary redraws
    }
}

// Implement Equatable for VideoLibraryRow
struct VideoLibraryRow: View, Equatable {
    let video: VideoJob
    @ObservedObject var viewModel: VideoLibraryViewModel

    static func == (lhs: VideoLibraryRow, rhs: VideoLibraryRow) -> Bool {
        // Only redraw if these properties change
        lhs.video.id == rhs.video.id &&
        lhs.video.status == rhs.video.status &&
        lhs.video.progress == rhs.video.progress
    }

    var body: some View {
        // ... view implementation
    }
}
```

---

## 7. CODE Organization

### 7.1 Mixed Responsibilities in Views

Covered in section 3.3 above.

---

## 8. MISSING Features (Architectural Gaps)

### 8.1 No Export/Import for Prompts

Users might want to:
- Export prompts as JSON for backup
- Share prompt libraries with others
- Import community prompt templates

### 8.2 No Video Management

Missing features:
- Rename videos
- Add notes/tags
- Search/filter
- Bulk operations

### 8.3 No Cost Tracking

App generates videos but doesn't track:
- Total spend
- Cost per day/week/month
- Budget warnings

### 8.4 No Queue Management

Cannot:
- Pause generation queue
- Cancel pending videos
- Prioritize certain videos

---

## 9. Implementation Roadmap

### Phase 1: Critical Fixes (Week 1)
**Priority: MUST DO**

1. **Day 1-2:** Refactor service initialization
   - Create `AppDependencies` container
   - Update all ViewModels for dependency injection
   - Update views to pass dependencies
   - Test thoroughly

2. **Day 3:** Fix threading model
   - Remove `@MainActor` from `VideoAPIService`
   - Verify ViewModels handle thread switching
   - Performance testing

3. **Day 4:** Fix state management
   - Refactor `PromptRow` to use `@Binding`
   - Test edit-in-place functionality
   - Verify no stale state

4. **Day 5:** Add task cancellation
   - Implement in `VideoPlayerCoordinator`
   - Fix `ConfigurationView` timing
   - Test rapid open/close scenarios

### Phase 2: High Priority (Week 2)
**Priority: SHOULD DO**

1. **Day 1-2:** Protocol abstractions + testing
   - Create `VideoAPIServiceProtocol`
   - Implement `MockVideoAPIService`
   - Write unit tests

2. **Day 3:** Error recovery
   - Implement `NetworkMonitor`
   - Add retry logic with exponential backoff
   - Improve error messages

3. **Day 4:** Memory optimization
   - Switch to streaming downloads
   - Test with large videos

4. **Day 5:** Logging cleanup
   - Add conditional compilation
   - Remove excessive production logs
   - Fix subsystem identifier

### Phase 3: Medium Priority (Week 3-4)
**Priority: NICE TO HAVE**

1. Pagination support
2. Caching layer (SwiftData)
3. Background polling
4. View decomposition
5. Centralize constants
6. Keychain error messages

### Phase 4: Low Priority (Future)
**Priority: WHEN TIME PERMITS**

1. Undo/redo
2. Accessibility
3. Analytics
4. Advanced security
5. Export/import
6. Cost tracking

---

## 10. POSITIVE Aspects

### What You Did RIGHT ✅

1. **Excellent Swift Concurrency Usage**
   - Proper async/await throughout
   - No callback hell
   - Clean asynchronous code

2. **Good MVVM Separation**
   - Clear Models, Views, ViewModels
   - Logical file organization
   - Proper use of `@Published` and `@ObservableObject`

3. **Comprehensive Logging System**
   - Well-organized subsystem-based logging
   - Good use of Apple's Unified Logging
   - Appropriate log levels (mostly)

4. **Secure Credential Storage**
   - Proper Keychain implementation
   - Correct accessibility settings
   - Good fallback to environment variables

5. **Custom Video Looping**
   - Excellent use of `AVPlayerLooper`
   - Seamless, gapless playback
   - Proper resource management

6. **Clean API Integration**
   - Well-structured `Codable` models
   - Proper `CodingKeys` usage
   - Good error typing

7. **SwiftUI Modal Patterns**
   - Good use of `Identifiable` wrapper for sheets
   - Proper modal lifecycle

8. **Coordinator Pattern**
   - Good start with `VideoPlayerCoordinator`
   - Centralized playback state

9. **Modern macOS Features**
   - Native SwiftUI throughout
   - No AppKit bridging (where not needed)
   - Good use of platform conventions

10. **Code Documentation**
    - Good inline comments
    - Clear function documentation
    - Helpful CLAUDE.md file

---

## Conclusion

SoraPlanner has a **solid architectural foundation** with excellent use of modern Swift and SwiftUI patterns. The critical issues are fixable and mostly stem from growing pains as the app evolved.

**Immediate Action Items:**
1. Fix service initialization pattern (dependency injection)
2. Remove `@MainActor` from service layer
3. Fix state management in `PromptRow`
4. Add task cancellation

**After fixing these, the app will be:**
- ✅ More testable
- ✅ More maintainable
- ✅ More performant
- ✅ More scalable
- ✅ Production-ready

The architecture is sound enough that these refactorings won't require a complete rewrite - they're incremental improvements to an already good codebase.

---

**Review conducted by:** SwiftUI Architecture Expert (Claude Code)
**Date:** October 10, 2025
**Status:** Ready for implementation
