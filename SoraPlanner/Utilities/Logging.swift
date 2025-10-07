//
//  Logging.swift
//  SoraPlanner
//
//  Centralized logging system using Apple's Unified Logging
//

import os

enum LogSubsystem: String {
    case api = "api"
    case ui = "ui"
    case video = "video"
    case networking = "networking"
    case keychain = "keychain"

    var logger: Logger {
        Logger(subsystem: "com.yourorg.SoraPlanner", category: self.rawValue)
    }
}

struct SoraPlannerLoggers {
    static let api = LogSubsystem.api.logger
    static let ui = LogSubsystem.ui.logger
    static let video = LogSubsystem.video.logger
    static let networking = LogSubsystem.networking.logger
    static let keychain = LogSubsystem.keychain.logger
}
