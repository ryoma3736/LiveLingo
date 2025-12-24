import Foundation
import Dependencies

// MARK: - Dependency Keys

/// STT Service Dependency
public struct STTServiceKey: DependencyKey {
    public static var liveValue: any STTServiceProtocol {
        fatalError("STT service not configured. Use withDependencies to provide an implementation.")
    }

    public static var testValue: any STTServiceProtocol {
        MockSTTService()
    }

    public static var previewValue: any STTServiceProtocol {
        MockSTTService()
    }
}

/// Translation Service Dependency
public struct TranslationServiceKey: DependencyKey {
    public static var liveValue: any TranslationServiceProtocol {
        fatalError("Translation service not configured. Use withDependencies to provide an implementation.")
    }

    public static var testValue: any TranslationServiceProtocol {
        MockTranslationService()
    }

    public static var previewValue: any TranslationServiceProtocol {
        MockTranslationService()
    }
}

/// TTS Service Dependency
public struct TTSServiceKey: DependencyKey {
    public static var liveValue: any TTSServiceProtocol {
        fatalError("TTS service not configured. Use withDependencies to provide an implementation.")
    }

    public static var testValue: any TTSServiceProtocol {
        MockTTSService()
    }

    public static var previewValue: any TTSServiceProtocol {
        MockTTSService()
    }
}

/// Conversation Repository Dependency
public struct ConversationRepositoryKey: DependencyKey {
    public static var liveValue: any ConversationRepositoryProtocol {
        fatalError("Conversation repository not configured.")
    }

    public static var testValue: any ConversationRepositoryProtocol {
        MockConversationRepository()
    }

    public static var previewValue: any ConversationRepositoryProtocol {
        MockConversationRepository()
    }
}

/// Settings Repository Dependency
public struct SettingsRepositoryKey: DependencyKey {
    public static var liveValue: any SettingsRepositoryProtocol {
        fatalError("Settings repository not configured.")
    }

    public static var testValue: any SettingsRepositoryProtocol {
        MockSettingsRepository()
    }

    public static var previewValue: any SettingsRepositoryProtocol {
        MockSettingsRepository()
    }
}

/// Glossary Repository Dependency
public struct GlossaryRepositoryKey: DependencyKey {
    public static var liveValue: any GlossaryRepositoryProtocol {
        fatalError("Glossary repository not configured.")
    }

    public static var testValue: any GlossaryRepositoryProtocol {
        MockGlossaryRepository()
    }

    public static var previewValue: any GlossaryRepositoryProtocol {
        MockGlossaryRepository()
    }
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    /// STT Service
    public var sttService: any STTServiceProtocol {
        get { self[STTServiceKey.self] }
        set { self[STTServiceKey.self] = newValue }
    }

    /// Translation Service
    public var translationService: any TranslationServiceProtocol {
        get { self[TranslationServiceKey.self] }
        set { self[TranslationServiceKey.self] = newValue }
    }

    /// TTS Service
    public var ttsService: any TTSServiceProtocol {
        get { self[TTSServiceKey.self] }
        set { self[TTSServiceKey.self] = newValue }
    }

    /// Conversation Repository
    public var conversationRepository: any ConversationRepositoryProtocol {
        get { self[ConversationRepositoryKey.self] }
        set { self[ConversationRepositoryKey.self] = newValue }
    }

    /// Settings Repository
    public var settingsRepository: any SettingsRepositoryProtocol {
        get { self[SettingsRepositoryKey.self] }
        set { self[SettingsRepositoryKey.self] = newValue }
    }

    /// Glossary Repository
    public var glossaryRepository: any GlossaryRepositoryProtocol {
        get { self[GlossaryRepositoryKey.self] }
        set { self[GlossaryRepositoryKey.self] = newValue }
    }
}

// MARK: - App Environment

/// Application environment configuration
public enum AppEnvironment: String, Sendable {
    case development
    case staging
    case production

    public static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    public var baseURL: String {
        switch self {
        case .development:
            return "https://dev-api.livelingo.app"
        case .staging:
            return "https://staging-api.livelingo.app"
        case .production:
            return "https://api.livelingo.app"
        }
    }
}
