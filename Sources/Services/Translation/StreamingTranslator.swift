import Foundation
import Combine

// MARK: - Streaming Configuration

/// Configuration for streaming translation
public struct StreamingTranslationConfig: Sendable {
    /// Wait-k value: number of source tokens to wait before translating
    public let waitK: Int

    /// Force flush interval (seconds)
    public let flushInterval: TimeInterval

    /// Minimum segment length before translation
    public let minSegmentLength: Int

    /// Maximum segment length before forced translation
    public let maxSegmentLength: Int

    /// Adaptive k based on sentence structure
    public let adaptiveK: Bool

    /// Target latency (milliseconds)
    public let targetLatency: Int

    public init(
        waitK: Int = 3,
        flushInterval: TimeInterval = 0.5,
        minSegmentLength: Int = 5,
        maxSegmentLength: Int = 50,
        adaptiveK: Bool = true,
        targetLatency: Int = 500
    ) {
        self.waitK = waitK
        self.flushInterval = flushInterval
        self.minSegmentLength = minSegmentLength
        self.maxSegmentLength = maxSegmentLength
        self.adaptiveK = adaptiveK
        self.targetLatency = targetLatency
    }

    public static let `default` = StreamingTranslationConfig()

    /// Low-latency configuration for real-time conversation
    public static let lowLatency = StreamingTranslationConfig(
        waitK: 2,
        flushInterval: 0.3,
        minSegmentLength: 3,
        maxSegmentLength: 30,
        targetLatency: 300
    )

    /// High-quality configuration for better translation
    public static let highQuality = StreamingTranslationConfig(
        waitK: 5,
        flushInterval: 0.8,
        minSegmentLength: 10,
        maxSegmentLength: 100,
        targetLatency: 800
    )
}

// MARK: - Streaming Translation State

public struct StreamingTranslationState: Sendable {
    public let pendingTokens: [String]
    public let translatedTokens: [String]
    public let currentK: Int
    public let latency: TimeInterval
    public let isComplete: Bool

    public init(
        pendingTokens: [String] = [],
        translatedTokens: [String] = [],
        currentK: Int = 3,
        latency: TimeInterval = 0,
        isComplete: Bool = false
    ) {
        self.pendingTokens = pendingTokens
        self.translatedTokens = translatedTokens
        self.currentK = currentK
        self.latency = latency
        self.isComplete = isComplete
    }
}

// MARK: - Streaming Translation Result

public struct StreamingTranslationResult: Sendable {
    public let partialTranslation: String
    public let isFinal: Bool
    public let confidence: Float
    public let latencyMs: Int
    public let tokensTranslated: Int
    public let tokensPending: Int
    public let timestamp: Date

    public init(
        partialTranslation: String,
        isFinal: Bool = false,
        confidence: Float = 1.0,
        latencyMs: Int = 0,
        tokensTranslated: Int = 0,
        tokensPending: Int = 0,
        timestamp: Date = Date()
    ) {
        self.partialTranslation = partialTranslation
        self.isFinal = isFinal
        self.confidence = confidence
        self.latencyMs = latencyMs
        self.tokensTranslated = tokensTranslated
        self.tokensPending = tokensPending
        self.timestamp = timestamp
    }
}

// MARK: - Wait-K Translator

/// Streaming translator using Wait-k strategy
public actor WaitKTranslator {
    // MARK: - Properties

    private let config: StreamingTranslationConfig
    private var buffer: [String] = []
    private var translatedSegments: [String] = []
    private var currentK: Int
    private var inputStartTime: Date?
    private var lastFlushTime: Date = Date()
    private var isComplete: Bool = false

    private let translationService: any TranslationServiceProtocol
    private var sourceLanguage: SupportedLanguage
    private var targetLanguage: SupportedLanguage

    // MARK: - Initialization

    public init(
        config: StreamingTranslationConfig = .default,
        translationService: any TranslationServiceProtocol,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) {
        self.config = config
        self.translationService = translationService
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.currentK = config.waitK
    }

    // MARK: - Public Methods

    /// Process a new token and potentially produce translation
    public func processToken(_ token: String) async -> StreamingTranslationResult? {
        if inputStartTime == nil {
            inputStartTime = Date()
        }

        buffer.append(token)

        // Check if we should translate
        guard shouldTranslate() else {
            return nil
        }

        return await translateBuffer(isFinal: false)
    }

    /// Flush remaining buffer and finalize translation
    public func flush() async -> StreamingTranslationResult {
        isComplete = true
        return await translateBuffer(isFinal: true)
    }

    /// Reset the translator for a new segment
    public func reset() {
        buffer.removeAll()
        translatedSegments.removeAll()
        inputStartTime = nil
        lastFlushTime = Date()
        isComplete = false
        currentK = config.waitK
    }

    /// Get current state
    public func getState() -> StreamingTranslationState {
        StreamingTranslationState(
            pendingTokens: buffer,
            translatedTokens: translatedSegments,
            currentK: currentK,
            latency: inputStartTime.map { Date().timeIntervalSince($0) } ?? 0,
            isComplete: isComplete
        )
    }

    /// Update language pair
    public func setLanguages(source: SupportedLanguage, target: SupportedLanguage) {
        sourceLanguage = source
        targetLanguage = target
    }

    // MARK: - Private Methods

    private func shouldTranslate() -> Bool {
        let tokenCount = buffer.count
        let timeSinceFlush = Date().timeIntervalSince(lastFlushTime)

        // Check various conditions for translation

        // 1. Wait-k condition: have enough tokens
        if tokenCount >= currentK {
            return true
        }

        // 2. Sentence-end detection
        if detectSentenceEnd() {
            return true
        }

        // 3. Force flush interval exceeded
        if timeSinceFlush >= config.flushInterval && tokenCount >= config.minSegmentLength {
            return true
        }

        // 4. Max segment length reached
        if tokenCount >= config.maxSegmentLength {
            return true
        }

        return false
    }

    private func detectSentenceEnd() -> Bool {
        guard let lastToken = buffer.last else { return false }

        // Japanese sentence endings
        let japaneseSentenceEnders = ["。", "！", "？", "…", "‼", "⁉"]

        // English sentence endings
        let englishSentenceEnders = [".", "!", "?", "..."]

        let allEnders = japaneseSentenceEnders + englishSentenceEnders

        return allEnders.contains { lastToken.contains($0) }
    }

    private func translateBuffer(isFinal: Bool) async -> StreamingTranslationResult {
        let startTime = Date()

        // Join buffer tokens into text
        let textToTranslate = buffer.joined()
        let tokenCount = buffer.count

        // Clear buffer (keeping some for context if adaptive)
        if config.adaptiveK && !isFinal {
            // Keep last few tokens for context in next translation
            let keepCount = min(2, buffer.count)
            buffer = Array(buffer.suffix(keepCount))
        } else {
            buffer.removeAll()
        }

        lastFlushTime = Date()

        // Translate
        do {
            let result = try await translationService.translate(
                textToTranslate,
                from: sourceLanguage,
                to: targetLanguage
            )

            translatedSegments.append(result.translatedText)

            // Adapt k value based on performance
            if config.adaptiveK {
                adaptKValue(latency: Date().timeIntervalSince(startTime))
            }

            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

            return StreamingTranslationResult(
                partialTranslation: result.translatedText,
                isFinal: isFinal,
                confidence: result.confidence,
                latencyMs: latencyMs,
                tokensTranslated: tokenCount,
                tokensPending: buffer.count,
                timestamp: Date()
            )
        } catch {
            // Return original text on error
            return StreamingTranslationResult(
                partialTranslation: textToTranslate,
                isFinal: isFinal,
                confidence: 0,
                latencyMs: Int(Date().timeIntervalSince(startTime) * 1000),
                tokensTranslated: tokenCount,
                tokensPending: buffer.count,
                timestamp: Date()
            )
        }
    }

    private func adaptKValue(latency: TimeInterval) {
        let latencyMs = Int(latency * 1000)
        let targetLatency = config.targetLatency

        if latencyMs > targetLatency + 100 {
            // Too slow, reduce k to decrease latency
            currentK = max(1, currentK - 1)
        } else if latencyMs < targetLatency - 100 {
            // Fast enough, can increase k for better quality
            currentK = min(config.waitK + 2, currentK + 1)
        }
    }
}

// MARK: - Streaming Translation Manager

/// Manages streaming translation with multiple strategies
public actor StreamingTranslationManager {
    // MARK: - Properties

    private let config: StreamingTranslationConfig
    private var translators: [UUID: WaitKTranslator] = [:]
    private let translationService: any TranslationServiceProtocol

    private nonisolated(unsafe) let resultSubject = PassthroughSubject<(UUID, StreamingTranslationResult), Never>()

    // MARK: - Public Stream

    public nonisolated var resultStream: AnyPublisher<(UUID, StreamingTranslationResult), Never> {
        resultSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(
        config: StreamingTranslationConfig = .default,
        translationService: any TranslationServiceProtocol
    ) {
        self.config = config
        self.translationService = translationService
    }

    // MARK: - Session Management

    /// Start a new translation session
    public func startSession(
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) -> UUID {
        let sessionID = UUID()
        let translator = WaitKTranslator(
            config: config,
            translationService: translationService,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        translators[sessionID] = translator
        return sessionID
    }

    /// End a translation session
    public func endSession(_ sessionID: UUID) async -> StreamingTranslationResult? {
        guard let translator = translators[sessionID] else { return nil }

        let result = await translator.flush()
        translators.removeValue(forKey: sessionID)

        resultSubject.send((sessionID, result))
        return result
    }

    /// Process token for a session
    public func processToken(_ token: String, for sessionID: UUID) async -> StreamingTranslationResult? {
        guard let translator = translators[sessionID] else { return nil }

        if let result = await translator.processToken(token) {
            resultSubject.send((sessionID, result))
            return result
        }
        return nil
    }

    /// Process multiple tokens at once
    public func processTokens(_ tokens: [String], for sessionID: UUID) async -> [StreamingTranslationResult] {
        var results: [StreamingTranslationResult] = []

        for token in tokens {
            if let result = await processToken(token, for: sessionID) {
                results.append(result)
            }
        }

        return results
    }

    /// Get session state
    public func getSessionState(_ sessionID: UUID) async -> StreamingTranslationState? {
        await translators[sessionID]?.getState()
    }

    /// Reset a session
    public func resetSession(_ sessionID: UUID) async {
        await translators[sessionID]?.reset()
    }
}

// MARK: - Text Tokenizer

/// Simple tokenizer for streaming translation
public struct TextTokenizer: Sendable {
    /// Tokenize text into words/phrases for Japanese
    public static func tokenizeJapanese(_ text: String) -> [String] {
        // For Japanese, we can tokenize by character or use morphological analysis
        // Simple approach: tokenize by punctuation and particle patterns

        var tokens: [String] = []
        var currentToken = ""

        for char in text {
            currentToken.append(char)

            // Check for natural break points
            if isJapaneseBreakPoint(char) {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    /// Tokenize text into words for English
    public static func tokenizeEnglish(_ text: String) -> [String] {
        text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }

    /// Tokenize based on detected language
    public static func tokenize(_ text: String, language: SupportedLanguage) -> [String] {
        switch language {
        case .japanese:
            return tokenizeJapanese(text)
        case .chineseSimplified, .chineseTraditional:
            // Chinese tokenization similar to Japanese
            return tokenizeJapanese(text)
        default:
            return tokenizeEnglish(text)
        }
    }

    private static func isJapaneseBreakPoint(_ char: Character) -> Bool {
        // Common Japanese particles and punctuation
        let breakPointStrings = ["。", "、", "！", "？", "…", "は", "が", "を", "に", "へ", "と", "の", "で", "も", "や"]
        let breakPoints: Set<Character> = Set(breakPointStrings.compactMap { $0.first })

        // Check if character is in break points
        if breakPoints.contains(char) {
            return true
        }

        // Check for punctuation
        if char.isPunctuation {
            return true
        }

        return false
    }
}
