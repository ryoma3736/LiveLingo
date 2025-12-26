import Foundation

/// Main error type for LiveLingo
public enum LiveLingoError: Error, LocalizedError, Sendable {
    // MARK: - Speech Recognition Errors
    case sttNotAvailable(reason: String)
    case sttPermissionDenied
    case sttRecognitionFailed(underlying: Error)
    case sttLanguageNotSupported(SupportedLanguage)
    case sttAlreadyRecognizing

    // MARK: - Translation Errors
    case translationFailed(underlying: Error)
    case translationProviderUnavailable(TranslationProvider)
    case translationLanguagePairNotSupported(from: SupportedLanguage, to: SupportedLanguage)
    case translationTimeout
    case translationRateLimited

    // MARK: - TTS Errors
    case ttsSynthesisFailed(reason: String)
    case ttsVoiceNotAvailable(VoiceOption)
    case ttsPlaybackFailed(underlying: Error)

    // MARK: - Audio Errors
    case audioSessionConfigurationFailed(underlying: Error)
    case audioSessionActivationFailed(underlying: Error)
    case audioInputUnavailable
    case audioOutputUnavailable
    case audioInterrupted
    case audioEncodingFailed(underlying: Error)

    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkRequestFailed(statusCode: Int, message: String)
    case networkInvalidResponse
    case networkInvalidURL
    case networkDecodingFailed(underlying: Error)
    case networkRateLimited

    // MARK: - Authentication Errors
    case authenticationRequired
    case authenticationFailed(reason: String)
    case authorizationFailed(underlying: Error)
    case sessionExpired
    case biometricAuthFailed

    // MARK: - Permission Errors
    case permissionDenied(permission: Permission)
    case permissionNotDetermined(permission: Permission)

    // MARK: - Storage Errors
    case storageFailed(underlying: Error)
    case storageNotFound(id: String)
    case storageCorrupted

    // MARK: - Configuration Errors
    case configurationInvalid(reason: String)
    case apiKeyMissing(service: String)

    // MARK: - Gemini Live API Errors
    case geminiAlreadyConnected
    case geminiNotConnected
    case geminiConnectionFailed(underlying: Error)
    case geminiSessionFailed(reason: String)

    // MARK: - General Errors
    case unknown(underlying: Error)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .sttNotAvailable(let reason):
            return "Speech recognition is not available: \(reason)"
        case .sttPermissionDenied:
            return "Speech recognition permission was denied"
        case .sttRecognitionFailed(let error):
            return "Speech recognition failed: \(error.localizedDescription)"
        case .sttLanguageNotSupported(let language):
            return "Language \(language.nativeName) is not supported for speech recognition"

        case .translationFailed(let error):
            return "Translation failed: \(error.localizedDescription)"
        case .translationProviderUnavailable(let provider):
            return "Translation provider \(provider.rawValue) is unavailable"
        case .translationLanguagePairNotSupported(let from, let to):
            return "Translation from \(from.nativeName) to \(to.nativeName) is not supported"
        case .translationTimeout:
            return "Translation request timed out"
        case .translationRateLimited:
            return "Translation rate limit exceeded"

        case .ttsSynthesisFailed(let reason):
            return "Voice synthesis failed: \(reason)"
        case .ttsVoiceNotAvailable(let voice):
            return "Voice \(voice.name) is not available"
        case .ttsPlaybackFailed(let error):
            return "Audio playback failed: \(error.localizedDescription)"

        case .audioSessionConfigurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        case .audioInputUnavailable:
            return "Microphone is not available"
        case .audioOutputUnavailable:
            return "Audio output is not available"
        case .audioInterrupted:
            return "Audio session was interrupted"

        case .networkUnavailable:
            return "No internet connection"
        case .networkTimeout:
            return "Network request timed out"
        case .networkRequestFailed(let statusCode, let message):
            return "Network request failed (\(statusCode)): \(message)"
        case .networkInvalidResponse:
            return "Invalid response from server"

        case .authenticationRequired:
            return "Authentication is required"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .sessionExpired:
            return "Session has expired"
        case .biometricAuthFailed:
            return "Biometric authentication failed"

        case .permissionDenied(let permission):
            return "\(permission.displayName) permission was denied"
        case .permissionNotDetermined(let permission):
            return "\(permission.displayName) permission has not been requested"

        case .storageFailed(let error):
            return "Storage operation failed: \(error.localizedDescription)"
        case .storageNotFound(let id):
            return "Item not found: \(id)"
        case .storageCorrupted:
            return "Storage data is corrupted"

        case .configurationInvalid(let reason):
            return "Invalid configuration: \(reason)"
        case .apiKeyMissing(let service):
            return "API key for \(service) is missing"

        case .sttAlreadyRecognizing:
            return "Speech recognition is already in progress"
        case .audioSessionActivationFailed(let error):
            return "Failed to activate audio session: \(error.localizedDescription)"
        case .audioEncodingFailed(let error):
            return "Failed to encode audio: \(error.localizedDescription)"
        case .networkInvalidURL:
            return "Invalid URL"
        case .networkDecodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkRateLimited:
            return "Rate limit exceeded"
        case .authorizationFailed(let error):
            return "Authorization failed: \(error.localizedDescription)"

        case .geminiAlreadyConnected:
            return "Gemini Live API is already connected"
        case .geminiNotConnected:
            return "Gemini Live API is not connected"
        case .geminiConnectionFailed(let error):
            return "Gemini connection failed: \(error.localizedDescription)"
        case .geminiSessionFailed(let reason):
            return "Gemini session failed: \(reason)"

        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        case .cancelled:
            return "Operation was cancelled"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .sttPermissionDenied, .permissionDenied:
            return "Please enable the permission in Settings."
        case .networkUnavailable:
            return "Please check your internet connection and try again."
        case .sessionExpired, .authenticationRequired:
            return "Please sign in again."
        case .translationRateLimited, .networkRateLimited:
            return "Please wait a moment and try again."
        case .geminiConnectionFailed, .geminiSessionFailed:
            return "Try reconnecting or check your network."
        case .audioInputUnavailable:
            return "Please check microphone permissions in Settings."
        case .audioInterrupted:
            return "Tap the microphone to start again."
        case .networkTimeout:
            return "Check your connection and try again."
        case .apiKeyMissing:
            return "Please configure the API key in settings."
        default:
            return nil
        }
    }

    /// Whether this error is recoverable by retrying
    public var isRetryable: Bool {
        switch self {
        case .networkTimeout, .networkUnavailable, .translationTimeout:
            return true
        case .geminiConnectionFailed, .geminiSessionFailed:
            return true
        case .audioInterrupted:
            return true
        case .networkRateLimited, .translationRateLimited:
            return true  // Retryable after delay
        case .sttRecognitionFailed:
            return true
        default:
            return false
        }
    }

    /// Recommended retry delay in seconds (for rate-limited errors)
    public var retryDelay: TimeInterval? {
        switch self {
        case .networkRateLimited, .translationRateLimited:
            return 5.0
        case .networkTimeout:
            return 1.0
        case .geminiConnectionFailed, .geminiSessionFailed:
            return 2.0
        default:
            return nil
        }
    }

    /// Action type for error recovery
    public var recoveryAction: ErrorRecoveryAction {
        switch self {
        case .sttPermissionDenied, .permissionDenied:
            return .openSettings
        case .networkUnavailable:
            return .checkNetwork
        case .geminiConnectionFailed, .geminiSessionFailed, .networkTimeout:
            return .retry
        case .audioInterrupted:
            return .restart
        case .translationRateLimited, .networkRateLimited:
            return .waitAndRetry
        case .apiKeyMissing:
            return .configure
        case .sessionExpired, .authenticationRequired:
            return .signIn
        default:
            return .none
        }
    }
}

/// Action types for error recovery
public enum ErrorRecoveryAction: String, Sendable {
    case none
    case retry
    case waitAndRetry
    case restart
    case openSettings
    case checkNetwork
    case configure
    case signIn
}

/// Permission types
public enum Permission: String, Sendable {
    case microphone = "microphone"
    case speechRecognition = "speech_recognition"
    case notifications = "notifications"

    public var displayName: String {
        switch self {
        case .microphone: return "Microphone"
        case .speechRecognition: return "Speech Recognition"
        case .notifications: return "Notifications"
        }
    }
}

/// Permission status
public enum PermissionStatus: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}
