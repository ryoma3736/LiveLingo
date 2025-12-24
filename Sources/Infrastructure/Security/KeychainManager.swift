import Foundation
import Security

// MARK: - Keychain Error

/// Errors that can occur during keychain operations
public enum KeychainError: Error, LocalizedError, Sendable {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case encodingFailed
    case decodingFailed
    case accessDenied

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status: \(status)"
        case .encodingFailed:
            return "Failed to encode data for keychain"
        case .decodingFailed:
            return "Failed to decode data from keychain"
        case .accessDenied:
            return "Access to keychain was denied"
        }
    }
}

// MARK: - Keychain Item

/// Keychain item keys
public enum KeychainKey: String, Sendable {
    case openAIAPIKey = "com.livelingo.openai-api-key"
    case anthropicAPIKey = "com.livelingo.anthropic-api-key"
    case coeFontAPIKey = "com.livelingo.coefont-api-key"
    case accessToken = "com.livelingo.access-token"
    case refreshToken = "com.livelingo.refresh-token"
    case userId = "com.livelingo.user-id"
}

// MARK: - Keychain Manager Protocol

/// Protocol for keychain operations
public protocol KeychainManagerProtocol: Sendable {
    func save(_ data: Data, for key: KeychainKey) throws
    func save(_ string: String, for key: KeychainKey) throws
    func load(key: KeychainKey) throws -> Data
    func loadString(key: KeychainKey) throws -> String
    func delete(key: KeychainKey) throws
    func exists(key: KeychainKey) -> Bool
    func clear() throws
}

// MARK: - Keychain Manager Implementation

/// Secure keychain storage manager
public final class KeychainManager: KeychainManagerProtocol, @unchecked Sendable {
    private let accessGroup: String?
    private let serviceName: String
    private let lock = NSLock()

    public static let shared = KeychainManager()

    public init(serviceName: String = "com.livelingo.app", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - Save Operations

    public func save(_ data: Data, for key: KeychainKey) throws {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(for: key)
        query[kSecValueData as String] = data

        // Try to update existing item first
        var status = SecItemUpdate(baseQuery(for: key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            status = SecItemAdd(query as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func save(_ string: String, for key: KeychainKey) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data, for: key)
    }

    public func save<T: Encodable>(_ object: T, for key: KeychainKey, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(object)
        try save(data, for: key)
    }

    // MARK: - Load Operations

    public func load(key: KeychainKey) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.decodingFailed
        }

        return data
    }

    public func loadString(key: KeychainKey) throws -> String {
        let data = try load(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return string
    }

    public func load<T: Decodable>(key: KeychainKey, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        let data = try load(key: key)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Delete Operations

    public func delete(key: KeychainKey) throws {
        lock.lock()
        defer { lock.unlock() }

        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func exists(key: KeychainKey) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        var query = baseQuery(for: key)
        query[kSecReturnData as String] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Private Methods

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

// MARK: - API Key Manager

/// Convenient wrapper for managing API keys
public actor APIKeyManager {
    private let keychain: KeychainManagerProtocol

    public init(keychain: KeychainManagerProtocol = KeychainManager.shared) {
        self.keychain = keychain
    }

    public var openAIAPIKey: String? {
        get { try? keychain.loadString(key: .openAIAPIKey) }
    }

    public var anthropicAPIKey: String? {
        get { try? keychain.loadString(key: .anthropicAPIKey) }
    }

    public var coeFontAPIKey: String? {
        get { try? keychain.loadString(key: .coeFontAPIKey) }
    }

    public func setOpenAIAPIKey(_ key: String) throws {
        try keychain.save(key, for: .openAIAPIKey)
    }

    public func setAnthropicAPIKey(_ key: String) throws {
        try keychain.save(key, for: .anthropicAPIKey)
    }

    public func setCoeFontAPIKey(_ key: String) throws {
        try keychain.save(key, for: .coeFontAPIKey)
    }

    public func clearAllAPIKeys() throws {
        try? keychain.delete(key: .openAIAPIKey)
        try? keychain.delete(key: .anthropicAPIKey)
        try? keychain.delete(key: .coeFontAPIKey)
    }

    public func hasAPIKey(for provider: TranslationProvider) -> Bool {
        switch provider {
        case .openAI:
            return keychain.exists(key: .openAIAPIKey)
        case .anthropic:
            return keychain.exists(key: .anthropicAPIKey)
        case .apple, .cache:
            return true
        }
    }
}
