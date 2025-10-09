# SoraPlanner

A native macOS application for creating and managing AI-generated videos using OpenAI's Sora-2 video generation API.

![Platform](https://img.shields.io/badge/platform-macOS%2026.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green)

## Overview

SoraPlanner provides an intuitive, native macOS interface for working with OpenAI's Sora-2 video generation platform. Create videos from text prompts, monitor generation progress in real-time, and manage your video library all from a clean, modern SwiftUI application.

### Features

- **Prompt Library Management**: Create, edit, and organize reusable video generation prompts with persistent storage
- **Modal Video Generation**: Launch video generation from prompts or create new videos on-demand
- **Flexible Duration Options**: Choose between 4, 8, or 12-second videos with transparent pricing
- **Real-Time Progress Tracking**: Monitor your video generation with live status updates
- **Video Library Management**: View all your generated videos with detailed metadata
- **Integrated Video Playback**: Watch your videos directly within the app with seamless looping
- **Secure API Key Management**: Store your OpenAI API key securely in macOS Keychain via Settings tab

## Setup

### Requirements

- macOS 26.0 or later
- Xcode 14.0 or later
- OpenAI API key with Video API access

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/SoraPlanner.git
   cd SoraPlanner
   ```

2. **Build and Run**
   - Open `SoraPlanner.xcodeproj` in Xcode
   - Press Cmd+R to build and run

3. **Configure API Key**

   The application requires an OpenAI API key for authentication.

   **Preferred Method: Settings Tab (Secure Keychain Storage)**
   - Launch the application
   - Navigate to the Settings tab
   - Enter your OpenAI API key in the secure field
   - Click "Save API Key"
   - The key is encrypted and stored in macOS Keychain
   - Persists between app launches

   **Alternative Method: Environment Variable (Legacy)**

   For development or backward compatibility, you can use an environment variable:

   - **Via Xcode Scheme**: Go to Product > Scheme > Edit Scheme... > Run > Arguments tab > Environment Variables, add `OPENAI_API_KEY` with your key
   - **Via Shell Profile**: Add `export OPENAI_API_KEY="your-api-key-here"` to ~/.zshrc or ~/.bash_profile and restart Xcode

   Note: Keychain storage takes precedence if both methods are configured.

---

**Note**: Video generation costs $0.10 per second according to OpenAI's pricing.
