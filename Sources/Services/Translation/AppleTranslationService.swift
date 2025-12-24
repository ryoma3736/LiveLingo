import Foundation
import NaturalLanguage

// MARK: - Apple Translation Service

/// Apple's on-device translation service
public actor AppleTranslationService: TranslationServiceProtocol {
    public let provider: TranslationProvider = .apple

    private var translationSession: Any? // iOS 17.4+ MLTranslationSession

    public init() {}

    // MARK: - Translation

    public func translate(
        _ text: String,
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage
    ) async throws -> TranslationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return TranslationResult(
                originalText: text,
                translatedText: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                provider: .apple,
                confidence: 1.0
            )
        }

        // Check availability
        guard await isAvailable(from: sourceLanguage, to: targetLanguage) else {
            throw LiveLingoError.translationLanguagePairNotSupported(
                from: sourceLanguage,
                to: targetLanguage
            )
        }

        // Use Apple Translation API (iOS 17.4+)
        let translatedText = try await performTranslation(
            text: text,
            from: sourceLanguage,
            to: targetLanguage
        )

        return TranslationResult(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            provider: .apple,
            confidence: calculateConfidence(original: text, translated: translatedText)
        )
    }

    public func streamTranslate(
        _ text: String,
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await translate(text, from: sourceLanguage, to: targetLanguage)
                    continuation.yield(result.translatedText)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func isAvailable(from sourceLanguage: SupportedLanguage, to targetLanguage: SupportedLanguage) async -> Bool {
        // Check if Apple Translation supports this language pair
        let supportedPairs: Set<String> = [
            "ja-JP:en-US", "en-US:ja-JP",
            "ja-JP:en-GB", "en-GB:ja-JP",
            "ja-JP:zh-CN", "zh-CN:ja-JP",
            "en-US:zh-CN", "zh-CN:en-US",
            "en-US:ko-KR", "ko-KR:en-US",
            "en-US:es-ES", "es-ES:en-US",
            "en-US:fr-FR", "fr-FR:en-US",
            "en-US:vi-VN", "vi-VN:en-US",
        ]

        let pairKey = "\(sourceLanguage.rawValue):\(targetLanguage.rawValue)"
        return supportedPairs.contains(pairKey)
    }

    // MARK: - Private Methods

    private func performTranslation(
        text: String,
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage
    ) async throws -> String {
        // In a real implementation, this would use MLTranslationSession
        // For now, we'll throw an error indicating the need for actual implementation
        #if targetEnvironment(simulator)
        // Return mock translation in simulator
        return "[Translated: \(text)]"
        #else
        throw LiveLingoError.translationFailed(
            underlying: NSError(
                domain: "AppleTranslation",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Translation API requires iOS 17.4+"]
            )
        )
        #endif
    }

    private func calculateConfidence(original: String, translated: String) -> Float {
        // Basic confidence calculation based on translation result
        guard !translated.isEmpty else { return 0 }
        guard translated != original else { return 0.5 } // Same text might indicate no translation

        // If the translation looks reasonable, return high confidence
        return 0.9
    }
}

// MARK: - Translation Manager

/// Manages multiple translation providers with fallback
public actor TranslationManager {
    private var providers: [TranslationProvider: any TranslationServiceProtocol] = [:]
    private let cache: TranslationCache
    private let preferredOrder: [TranslationProvider]

    public init(
        preferredOrder: [TranslationProvider] = [.apple, .openAI, .anthropic],
        cache: TranslationCache = TranslationCache()
    ) {
        self.preferredOrder = preferredOrder
        self.cache = cache
    }

    public func registerProvider(_ provider: TranslationProvider, service: any TranslationServiceProtocol) {
        providers[provider] = service
    }

    public func translate(
        _ text: String,
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage,
        context: TranslationContext? = nil
    ) async throws -> TranslationResult {
        // Check cache first
        if let cached = await cache.get(text: text, from: sourceLanguage, to: targetLanguage) {
            return cached
        }

        // Try providers in preferred order
        var lastError: Error?

        for provider in preferredOrder {
            guard let service = providers[provider] else { continue }

            do {
                let result = try await service.translate(text, from: sourceLanguage, to: targetLanguage)

                // Cache the result
                await cache.set(result)

                return result
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? LiveLingoError.translationProviderUnavailable(.apple)
    }

    public func availableProviders(
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage
    ) async -> [TranslationProvider] {
        var available: [TranslationProvider] = []

        for (provider, service) in providers {
            if await service.isAvailable(from: sourceLanguage, to: targetLanguage) {
                available.append(provider)
            }
        }

        return available.sorted { p1, p2 in
            let i1 = preferredOrder.firstIndex(of: p1) ?? Int.max
            let i2 = preferredOrder.firstIndex(of: p2) ?? Int.max
            return i1 < i2
        }
    }
}

// MARK: - Translation Context

/// Context for improving translation quality
public struct TranslationContext: Sendable {
    public let domain: TranslationDomain
    public let glossary: Glossary?
    public let previousTranslations: [TranslationResult]

    public init(
        domain: TranslationDomain = .general,
        glossary: Glossary? = nil,
        previousTranslations: [TranslationResult] = []
    ) {
        self.domain = domain
        self.glossary = glossary
        self.previousTranslations = previousTranslations
    }
}

public enum TranslationDomain: String, Sendable {
    case general
    case business
    case medical
    case legal
    case technical
    case casual
}

// MARK: - Translation Cache

/// In-memory cache for translations
public actor TranslationCache {
    private var cache: [String: CachedTranslation] = [:]
    private let maxSize: Int
    private let ttl: TimeInterval

    public init(maxSize: Int = 1000, ttl: TimeInterval = 3600) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    public func get(
        text: String,
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage
    ) -> TranslationResult? {
        let key = cacheKey(text: text, from: sourceLanguage, to: targetLanguage)

        guard let cached = cache[key] else { return nil }
        guard Date().timeIntervalSince(cached.timestamp) < ttl else {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.result
    }

    public func set(_ result: TranslationResult) {
        let key = cacheKey(
            text: result.originalText,
            from: result.sourceLanguage,
            to: result.targetLanguage
        )

        // Evict old entries if cache is full
        if cache.count >= maxSize {
            evictOldest()
        }

        cache[key] = CachedTranslation(result: result, timestamp: Date())
    }

    public func clear() {
        cache.removeAll()
    }

    private func cacheKey(
        text: String,
        from sourceLanguage: SupportedLanguage,
        to targetLanguage: SupportedLanguage
    ) -> String {
        "\(sourceLanguage.rawValue):\(targetLanguage.rawValue):\(text.hashValue)"
    }

    private func evictOldest() {
        guard let oldest = cache.min(by: { $0.value.timestamp < $1.value.timestamp }) else { return }
        cache.removeValue(forKey: oldest.key)
    }
}

private struct CachedTranslation {
    let result: TranslationResult
    let timestamp: Date
}
