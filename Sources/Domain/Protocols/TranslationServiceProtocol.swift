import Foundation

/// Protocol for Translation services
public protocol TranslationServiceProtocol: Sendable {
    /// Translate text from one language to another
    /// - Parameters:
    ///   - text: The text to translate
    ///   - from: Source language
    ///   - to: Target language
    /// - Returns: The translation result
    func translate(_ text: String, from: SupportedLanguage, to: SupportedLanguage) async throws -> TranslationResult

    /// Stream translation for real-time output
    /// - Parameters:
    ///   - text: The text to translate
    ///   - from: Source language
    ///   - to: Target language
    /// - Returns: An async stream of partial translations
    func streamTranslate(_ text: String, from: SupportedLanguage, to: SupportedLanguage) -> AsyncThrowingStream<String, Error>

    /// Check if translation is available for a language pair
    func isAvailable(from: SupportedLanguage, to: SupportedLanguage) -> Bool

    /// The provider type for this service
    var provider: TranslationProvider { get }
}

/// Protocol for Translation Context Management
public protocol TranslationContextProtocol: Sendable {
    /// Add a conversation turn to the context
    func addTurn(original: String, translated: String)

    /// Build a context-aware prompt for translation
    func buildPrompt(for text: String) -> String

    /// Clear the context
    func clearContext()

    /// The maximum number of turns to keep in context
    var maxTurns: Int { get set }
}

/// Protocol for Glossary Management
public protocol GlossaryManagerProtocol: Sendable {
    /// Apply glossary replacements to text
    func applyGlossary(_ text: String, glossary: Glossary) -> String

    /// Verify glossary terms in translation
    func verifyTerms(in translation: String, glossary: Glossary) -> Bool

    /// Get all active glossaries
    var activeGlossaries: [Glossary] { get }
}

/// Protocol for Translation Caching
public protocol TranslationCacheProtocol: Sendable {
    /// Get a cached translation
    func get(key: String) async -> TranslationResult?

    /// Store a translation in cache
    func set(_ translation: TranslationResult, for key: String) async

    /// Clear the cache
    func clear() async

    /// The maximum number of entries in the cache
    var maxEntries: Int { get }

    /// Current cache hit rate
    var hitRate: Float { get }
}
