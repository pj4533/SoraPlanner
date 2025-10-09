//
//  ContentView.swift
//  SoraPlanner
//
//  Main content view with tabbed interface and shared video player
//

import SwiftUI

struct ContentView: View {
    @StateObject private var playerCoordinator = VideoPlayerCoordinator()
    @State private var showGenerationModal = false
    @State private var promptToGenerate: String?

    var body: some View {
        TabView {
            PromptLibraryView(
                onGeneratePrompt: { prompt in
                    promptToGenerate = prompt
                    showGenerationModal = true
                },
                onGenerateEmpty: {
                    promptToGenerate = nil
                    showGenerationModal = true
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
        .sheet(isPresented: $showGenerationModal, onDismiss: {
            // Reset prompt when modal is dismissed
            promptToGenerate = nil
        }) {
            VideoGenerationView(initialPrompt: promptToGenerate)
                .environmentObject(playerCoordinator)
        }
    }
}

#Preview {
    ContentView()
}
