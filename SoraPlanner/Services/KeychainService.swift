//
//  KeychainService.swift
//  SoraPlanner
//
//  Secure storage service for API keys using macOS Keychain Services.
//

import Foundation
import Security
import os.log

/// Service for securely storing and retrieving sensitive data using macOS Keychain
class KeychainService {
    static let shared = KeychainService()

    private let logger = SoraPlannerLoggers.keychain
    private let service: String
    private let account = "openai-api-key"

    private init() {
        // Use bundle identifier as service identifier
        self.service = Bundle.main.bundleIdentifier ?? "com.soraplanner.app"
    }

    /// Saves the API key to the keychain
    /// - Parameter key: The API key to store
    /// - Throws: KeychainError if the save operation fails
    func saveAPIKey(_ key: String) throws {
        let keyData = key.data(using: .utf8)!

        // First, try to delete any existing key
        try? deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to save API key to keychain: \(status)")
            throw KeychainError.saveFailed(status: status)
        }

        logger.info("API key successfully saved to keychain")
    }

    /// Retrieves the API key from the keychain
    /// - Returns: The stored API key, or nil if not found
    func retrieveAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                logger.warning("Failed to retrieve API key from keychain: \(status)")
            }
            return nil
        }

        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            logger.error("Failed to decode API key from keychain data")
            return nil
        }

        logger.debug("API key successfully retrieved from keychain")
        return key
    }

    /// Deletes the API key from the keychain
    /// - Throws: KeychainError if the delete operation fails
    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete API key from keychain: \(status)")
            throw KeychainError.deleteFailed(status: status)
        }

        logger.info("API key deleted from keychain")
    }

    /// Checks if an API key is currently stored in the keychain
    /// - Returns: True if a key exists, false otherwise
    func hasAPIKey() -> Bool {
        return retrieveAPIKey() != nil
    }
}

/// Errors that can occur during keychain operations
enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save API key to keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete API key from keychain (status: \(status))"
        }
    }
}
