import Foundation

/// A single transcript entry in a conversation
public struct TranscriptItem: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let speaker: SpeakerID
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public let originalText: String
    public let translatedText: String
    public let confidence: Float
    public let isFinal: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        speaker: SpeakerID,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        originalText: String,
        translatedText: String,
        confidence: Float = 1.0,
        isFinal: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.speaker = speaker
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.originalText = originalText
        self.translatedText = translatedText
        self.confidence = confidence
        self.isFinal = isFinal
    }
}

/// Result from speech recognition
public struct RecognitionResult: Sendable {
    public let text: String
    public let isFinal: Bool
    public let speakerID: SpeakerID
    public let confidence: Float
    public let language: SupportedLanguage
    public let timestamp: Date

    public init(
        text: String,
        isFinal: Bool,
        speakerID: SpeakerID = .unknown,
        confidence: Float = 1.0,
        language: SupportedLanguage,
        timestamp: Date = Date()
    ) {
        self.text = text
        self.isFinal = isFinal
        self.speakerID = speakerID
        self.confidence = confidence
        self.language = language
        self.timestamp = timestamp
    }
}

/// Result from translation
public struct TranslationResult: Sendable {
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public let provider: TranslationProvider
    public let confidence: Float
    public let cachedAt: Date?

    public init(
        originalText: String,
        translatedText: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        provider: TranslationProvider,
        confidence: Float = 1.0,
        cachedAt: Date? = nil
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provider = provider
        self.confidence = confidence
        self.cachedAt = cachedAt
    }
}

/// Translation provider types
public enum TranslationProvider: String, Codable, Sendable {
    case apple = "apple"
    case openAI = "openai"
    case anthropic = "anthropic"
    case cache = "cache"
}
