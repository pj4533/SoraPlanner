//
//  ContentView.swift
//  SoraPlanner
//
//  Main content view with tabbed interface and shared video player
//

import SwiftUI

// Identifiable wrapper for sheet presentation with proper view identity
struct VideoGenerationRequest: Identifiable {
    let id = UUID()
    let initialPrompt: String?
}

struct ContentView: View {
    @StateObject private var playerCoordinator = VideoPlayerCoordinator()
    @State private var generationRequest: VideoGenerationRequest?
    @State private var showGenerationSuccess = false

    var body: some View {
        TabView {
            PromptLibraryView(
                onGeneratePrompt: { prompt in
                    generationRequest = VideoGenerationRequest(initialPrompt: prompt)
                },
                onGenerateEmpty: {
                    generationRequest = VideoGenerationRequest(initialPrompt: nil)
                }
            )
            .tabItem {
                Label("Prompts", systemImage: "doc.text.fill")
            }

            VideoLibraryView()
                .tabItem {
                    Label("Library", systemImage: "video.stack")
                }

            ConfigurationView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .frame(minWidth: 650, minHeight: 750)
        .environmentObject(playerCoordinator)
        .sheet(item: $playerCoordinator.currentVideo) { video in
            VideoPlayerView(video: video)
                .environmentObject(playerCoordinator)
        }
        .sheet(item: $generationRequest) { request in
            VideoGenerationView(
                initialPrompt: request.initialPrompt,
                onGenerationSuccess: {
                    showGenerationSuccess = true
                }
            )
            .environmentObject(playerCoordinator)
        }
        .alert("Generation Queued", isPresented: $showGenerationSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your video has been queued for generation. Check the Library tab to monitor its progress.")
        }
    }
}

#Preview {
    ContentView()
}
