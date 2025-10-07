//
//  ContentView.swift
//  SoraPlanner
//
//  Main content view with tabbed interface
//

import SwiftUI

struct ContentView: View {
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
        }
        .frame(minWidth: 650, minHeight: 750)
    }
}

#Preview {
    ContentView()
}
