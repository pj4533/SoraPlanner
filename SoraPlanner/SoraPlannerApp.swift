//
//  SoraPlannerApp.swift
//  SoraPlanner
//
//  Created by PJ Gray on 10/7/25.
//

import SwiftUI

@main
struct SoraPlannerApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            if dependencies.isInitialized, let apiService = dependencies.apiService {
                ContentView(apiService: apiService)
                    .environmentObject(dependencies)
            } else {
                InitializationErrorView(
                    error: dependencies.initializationError,
                    onRetry: { dependencies.reinitialize() }
                )
            }
        }
    }
}
