//
//  DecodingLogger.swift
//  SoraPlanner
//
//  Reusable JSON decoding utility with comprehensive error logging
//

import Foundation
import os

struct DecodingLogger {
    /// Decode JSON data with detailed error logging
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - data: The JSON data to decode
    ///   - context: A description of where this decoding is happening (e.g., "GET /v1/videos/{id}")
    /// - Returns: The decoded object
    /// - Throws: DecodingError with comprehensive logging
    static func decode<T: Decodable>(_ type: T.Type, from data: Data, context: String) throws -> T {
        let decoder = JSONDecoder()

        do {
            let result = try decoder.decode(type, from: data)
            SoraPlannerLoggers.api.debug("✅ Successfully decoded \(String(describing: type)) for \(context)")
            return result

        } catch let DecodingError.keyNotFound(key, context) {
            // Log missing key error
            let errorMessage = """
            ❌ DECODING ERROR: Key not found
            Context: \(context)
            Type: \(String(describing: type))
            Missing Key: \(key.stringValue)
            Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
            Debug Description: \(context.debugDescription)

            Raw JSON Response:
            \(prettyPrintJSON(data))
            """
            SoraPlannerLoggers.api.error("\(errorMessage)")
            throw DecodingError.keyNotFound(key, context)

        } catch let DecodingError.typeMismatch(type, context) {
            // Log type mismatch error
            let errorMessage = """
            ❌ DECODING ERROR: Type mismatch
            Context: \(context)
            Expected Type: \(String(describing: type))
            Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
            Debug Description: \(context.debugDescription)

            Raw JSON Response:
            \(prettyPrintJSON(data))
            """
            SoraPlannerLoggers.api.error("\(errorMessage)")
            throw DecodingError.typeMismatch(type, context)

        } catch let DecodingError.valueNotFound(type, context) {
            // Log value not found error
            let errorMessage = """
            ❌ DECODING ERROR: Value not found
            Context: \(context)
            Type: \(String(describing: type))
            Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
            Debug Description: \(context.debugDescription)

            Raw JSON Response:
            \(prettyPrintJSON(data))
            """
            SoraPlannerLoggers.api.error("\(errorMessage)")
            throw DecodingError.valueNotFound(type, context)

        } catch let DecodingError.dataCorrupted(context) {
            // Log data corrupted error
            let errorMessage = """
            ❌ DECODING ERROR: Data corrupted
            Context: \(context)
            Coding Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))
            Debug Description: \(context.debugDescription)

            Raw JSON Response:
            \(prettyPrintJSON(data))
            """
            SoraPlannerLoggers.api.error("\(errorMessage)")
            throw DecodingError.dataCorrupted(context)

        } catch {
            // Log unexpected error
            let errorMessage = """
            ❌ DECODING ERROR: Unexpected error
            Context: \(context)
            Type: \(String(describing: type))
            Error: \(error.localizedDescription)

            Raw JSON Response:
            \(prettyPrintJSON(data))
            """
            SoraPlannerLoggers.api.error("\(errorMessage)")
            throw error
        }
    }

    /// Pretty-print JSON data for logging
    private static func prettyPrintJSON(_ data: Data) -> String {
        // First try to parse as JSON and pretty-print
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        // Fallback to raw string
        if let rawString = String(data: data, encoding: .utf8) {
            return rawString
        }

        // Last resort: hex dump
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
