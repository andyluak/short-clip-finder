//
//  KeychainManager.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import Foundation
import Security

enum KeychainError: LocalizedError {
    case duplicateEntry
    case unknown(OSStatus)
    case notFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .duplicateEntry:
            "Item already exists in Keychain."
        case .unknown(let status):
            "Keychain error: \(status)"
        case .notFound:
            "Item not found in Keychain."
        case .invalidData:
            "Invalid data format."
        }
    }
}

struct KeychainManager {
    private static let service = "com.clipfinder.api-keys"

    enum Key: String {
        case openAI = "openai-api-key"
    }

    static func save(key: Key, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    static func get(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    static func delete(key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    static var hasOpenAIKey: Bool {
        Self.get(key: .openAI) != nil
    }
}
