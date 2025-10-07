//
//  DecodingErrorLogger.swift
//  SoraPlanner
//
//  Simple helper functions for logging decoding errors with context
//

import Foundation
import os

extension DecodingError {
    /// Get a detailed description of the decoding error
    func detailedDescription() -> String {
        switch self {
        case .keyNotFound(let key, let context):
            return "Key '\(key.stringValue)' not found. Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"

        case .typeMismatch(let type, let context):
            return "Type mismatch for type '\(type)'. Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"

        case .valueNotFound(let type, let context):
            return "Value not found for type '\(type)'. Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))"

        case .dataCorrupted(let context):
            return "Data corrupted. Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")). \(context.debugDescription)"

        @unknown default:
            return localizedDescription
        }
    }
}

/// Log a decoding error with raw JSON response
func logDecodingError(_ error: DecodingError, data: Data, context: String) {
    let errorDetails = error.detailedDescription()
    let rawJSON = String(data: data, encoding: .utf8) ?? "<unable to decode data>"

    SoraPlannerLoggers.api.error("""
    Decoding error for \(context):
    \(errorDetails)
    Raw JSON: \(rawJSON)
    """)
}
