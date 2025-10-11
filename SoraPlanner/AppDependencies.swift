//
//  AppDependencies.swift
//  SoraPlanner
//
//  Centralized dependency container for app-level services
//

import SwiftUI
import Combine
import os

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
