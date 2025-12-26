import Foundation

// MARK: - API Keys Configuration
// ⚠️ SECURITY: All API keys are stored securely in Keychain
// Never hardcode API keys in source code

public enum Secrets {
    /// Get Gemini API Key from Keychain (synchronous wrapper)
    public static var geminiAPIKey: String {
        get {
            // Use KeychainManager directly for synchronous access
            if let key = try? KeychainManager.shared.loadString(key: .geminiAPIKey) {
                return key
            }
            return ""
        }
    }

    /// Check if Gemini API is configured
    public static var isGeminiConfigured: Bool {
        KeychainManager.shared.exists(key: .geminiAPIKey)
    }

    /// Save Gemini API Key to Keychain
    public static func setGeminiAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw KeychainError.encodingFailed
        }
        try KeychainManager.shared.save(key, for: .geminiAPIKey)
    }

    /// Delete Gemini API Key from Keychain
    public static func deleteGeminiAPIKey() throws {
        try KeychainManager.shared.delete(key: .geminiAPIKey)
    }
}
