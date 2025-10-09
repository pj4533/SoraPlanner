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
    @State private var showGenerationSuccess = false

    var body: some View {
        TabView {
            PromptLibraryView(
                onGeneratePrompt: { prompt in
                    print("DEBUG: Setting promptToGenerate to: '\(prompt)'")
                    promptToGenerate = prompt
                    showGenerationModal = true
                },
                onGenerateEmpty: {
                    print("DEBUG: Setting promptToGenerate to nil")
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
            VideoGenerationView(
                initialPrompt: promptToGenerate,
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
