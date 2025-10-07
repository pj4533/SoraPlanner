//
//  ContentView.swift
//  SoraPlanner
//
//  Main content view with tabbed interface and shared video player
//

import SwiftUI

struct ContentView: View {
    @StateObject private var playerCoordinator = VideoPlayerCoordinator()

    var body: some View {
        TabView {
            VideoGenerationView()
                .tabItem {
                    Label("Generate", systemImage: "wand.and.stars")
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
    }
}

#Preview {
    ContentView()
}
