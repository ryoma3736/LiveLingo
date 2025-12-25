import Foundation

// MARK: - API Keys Configuration
// ⚠️ WARNING: Do not commit real API keys to version control
// In production, use Keychain or secure configuration management

public enum Secrets {
    /// Gemini Live API Key
    public static let geminiAPIKey = "AIzaSyAes4RJ_QlIkjpEjss96VR3m6TFMzL1rDY"

    /// Check if Gemini API is configured
    public static var isGeminiConfigured: Bool {
        !geminiAPIKey.isEmpty && geminiAPIKey != "YOUR_API_KEY_HERE"
    }
}
