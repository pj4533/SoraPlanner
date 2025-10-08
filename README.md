# SoraPlanner

A native macOS application for creating and managing AI-generated videos using OpenAI's Sora-2 video generation API.

![Platform](https://img.shields.io/badge/platform-macOS%2026.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-green)

## Overview

SoraPlanner provides an intuitive, native macOS interface for working with OpenAI's Sora-2 video generation platform. Create videos from text prompts, monitor generation progress in real-time, and manage your video library all from a clean, modern SwiftUI application.

### Features

- **Text-to-Video Creation**: Enter natural language prompts to generate videos
- **Flexible Duration Options**: Choose between 4, 10, or 30-second videos
- **Real-Time Progress Tracking**: Monitor your video generation with live status updates
- **Video Library Management**: View all your generated videos with detailed metadata
- **Integrated Video Playback**: Watch your videos directly within the app with seamless looping

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

2. **Configure API Key**

   Set your OpenAI API key as an environment variable:

   **Via Xcode Scheme (Recommended)**
   - Open `SoraPlanner.xcodeproj` in Xcode
   - Go to Product > Scheme > Edit Scheme...
   - Select "Run" > "Arguments" tab
   - Under "Environment Variables", add:
     - Name: `OPENAI_API_KEY`
     - Value: `your-api-key-here`

   **Via Shell Profile**
   - Add to ~/.zshrc or ~/.bash_profile:
     ```bash
     export OPENAI_API_KEY="your-api-key-here"
     ```
   - Restart Xcode

3. **Build and Run**
   - Open `SoraPlanner.xcodeproj` in Xcode
   - Press Cmd+R to build and run

---

**Note**: Video generation costs $0.10 per second according to OpenAI's pricing.
