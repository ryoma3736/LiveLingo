import Foundation

// MARK: - Conversation Turn

/// A single turn in a conversation
public struct ConversationTurn: Sendable, Identifiable {
    public let id: UUID
    public let speaker: SpeakerID
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        speaker: SpeakerID = .unknown,
        originalText: String,
        translatedText: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.speaker = speaker
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
    }
}

// MARK: - Conversation Context

/// Context information for context-aware translation
public struct ConversationContext: Sendable {
    public let turns: [ConversationTurn]
    public let currentSpeaker: SpeakerID
    public let speakerStyles: [SpeakerID: SpeakerStyle]
    public let topics: [String]
    public let entities: [String: String] // Referenced entities: key -> description

    public init(
        turns: [ConversationTurn],
        currentSpeaker: SpeakerID = .unknown,
        speakerStyles: [SpeakerID: SpeakerStyle] = [:],
        topics: [String] = [],
        entities: [String: String] = [:]
    ) {
        self.turns = turns
        self.currentSpeaker = currentSpeaker
        self.speakerStyles = speakerStyles
        self.topics = topics
        self.entities = entities
    }

    /// Empty context
    public static let empty = ConversationContext(turns: [])
}

// MARK: - Speaker Style

/// Style characteristics for a speaker
public struct SpeakerStyle: Sendable {
    public let formality: FormalityLevel
    public let verbosity: VerbosityLevel
    public let preferredTerms: [String: String] // term -> preferred translation

    public init(
        formality: FormalityLevel = .neutral,
        verbosity: VerbosityLevel = .medium,
        preferredTerms: [String: String] = [:]
    ) {
        self.formality = formality
        self.verbosity = verbosity
        self.preferredTerms = preferredTerms
    }

    public enum FormalityLevel: String, Sendable {
        case formal
        case neutral
        case casual
    }

    public enum VerbosityLevel: String, Sendable {
        case concise
        case medium
        case verbose
    }
}

// MARK: - Context Manager Configuration

public struct ContextManagerConfig: Sendable {
    /// Maximum number of turns to keep in context
    public let maxTurns: Int

    /// Maximum age of turns to keep (seconds)
    public let maxTurnAge: TimeInterval

    /// Enable automatic topic extraction
    public let enableTopicExtraction: Bool

    /// Enable automatic entity tracking
    public let enableEntityTracking: Bool

    /// Enable speaker style learning
    public let enableStyleLearning: Bool

    public init(
        maxTurns: Int = 10,
        maxTurnAge: TimeInterval = 600, // 10 minutes
        enableTopicExtraction: Bool = true,
        enableEntityTracking: Bool = true,
        enableStyleLearning: Bool = true
    ) {
        self.maxTurns = maxTurns
        self.maxTurnAge = maxTurnAge
        self.enableTopicExtraction = enableTopicExtraction
        self.enableEntityTracking = enableEntityTracking
        self.enableStyleLearning = enableStyleLearning
    }

    public static let `default` = ContextManagerConfig()

    public static let minimal = ContextManagerConfig(
        maxTurns: 5,
        enableTopicExtraction: false,
        enableEntityTracking: false,
        enableStyleLearning: false
    )
}

// MARK: - Conversation Context Manager

/// Manages conversation context for context-aware translation
public actor ConversationContextManager: TranslationContextProtocol {
    // MARK: - Properties

    private let config: ContextManagerConfig
    private var turns: [ConversationTurn] = []
    private var speakerStyles: [SpeakerID: SpeakerStyle] = [:]
    private var extractedTopics: [String] = []
    private var trackedEntities: [String: String] = [:]

    public nonisolated var maxTurns: Int {
        get { 10 }
        set { }
    }

    // MARK: - Initialization

    public init(config: ContextManagerConfig = .default) {
        self.config = config
    }

    // MARK: - TranslationContextProtocol

    public nonisolated func addTurn(original: String, translated: String) {
        Task {
            await _addTurn(
                ConversationTurn(
                    originalText: original,
                    translatedText: translated,
                    sourceLanguage: .japanese,
                    targetLanguage: .englishUS
                )
            )
        }
    }

    public nonisolated func buildPrompt(for text: String) -> String {
        // Return synchronously with minimal context
        return text
    }

    public nonisolated func clearContext() {
        Task { await _clearContext() }
    }

    // MARK: - Extended API

    /// Add a turn with full details
    public func addTurn(_ turn: ConversationTurn) async {
        await _addTurn(turn)
    }

    private func _addTurn(_ turn: ConversationTurn) {
        turns.append(turn)

        // Prune old turns
        pruneTurns()

        // Extract information if enabled
        if config.enableTopicExtraction {
            extractTopics(from: turn)
        }

        if config.enableEntityTracking {
            trackEntities(from: turn)
        }

        if config.enableStyleLearning {
            learnSpeakerStyle(from: turn)
        }
    }

    /// Get the current context
    public func getContext() -> ConversationContext {
        ConversationContext(
            turns: turns,
            speakerStyles: speakerStyles,
            topics: extractedTopics,
            entities: trackedEntities
        )
    }

    /// Build a context-aware prompt for LLM translation
    public func buildContextPrompt(for text: String, targetLanguage: SupportedLanguage) async -> String {
        var prompt = ""

        // Add conversation history if available
        if !turns.isEmpty {
            prompt += "Previous conversation:\n"
            for turn in turns.suffix(config.maxTurns) {
                let speaker = turn.speaker == .speaker1 ? "Speaker A" : "Speaker B"
                prompt += "\(speaker): \(turn.originalText) -> \(turn.translatedText)\n"
            }
            prompt += "\n"
        }

        // Add entity references
        if !trackedEntities.isEmpty && config.enableEntityTracking {
            prompt += "Referenced entities:\n"
            for (entity, description) in trackedEntities {
                prompt += "- \(entity): \(description)\n"
            }
            prompt += "\n"
        }

        // Add topics
        if !extractedTopics.isEmpty && config.enableTopicExtraction {
            prompt += "Current topics: \(extractedTopics.joined(separator: ", "))\n\n"
        }

        // Add the text to translate
        prompt += "Translate the following to \(targetLanguage.nativeName), considering the context above:\n"
        prompt += text

        return prompt
    }

    /// Resolve pronouns and demonstratives based on context
    public func resolveReferences(in text: String) async -> ResolvedText {
        var resolved = text
        var resolutions: [ReferenceResolution] = []

        // Japanese demonstratives
        let demonstratives = [
            "さっきの": "the previous",
            "あれ": "that",
            "これ": "this",
            "それ": "it",
            "あの": "that",
            "この": "this",
            "その": "the"
        ]

        // Check for demonstratives that need context
        for (japanese, english) in demonstratives {
            if text.contains(japanese) {
                // Try to find referent in recent context
                if let referent = findReferent(for: japanese, in: turns) {
                    let resolution = ReferenceResolution(
                        original: japanese,
                        resolved: referent.text,
                        confidence: referent.confidence,
                        source: .contextHistory
                    )
                    resolutions.append(resolution)
                    resolved = resolved.replacingOccurrences(of: japanese, with: "[\(japanese)→\(referent.text)]")
                }
            }
        }

        return ResolvedText(
            originalText: text,
            resolvedText: resolved,
            resolutions: resolutions
        )
    }

    /// Clear all context
    public func clear() async {
        await _clearContext()
    }

    private func _clearContext() {
        turns.removeAll()
        speakerStyles.removeAll()
        extractedTopics.removeAll()
        trackedEntities.removeAll()
    }

    /// Get turns for a specific speaker
    public func getTurns(for speaker: SpeakerID) -> [ConversationTurn] {
        turns.filter { $0.speaker == speaker }
    }

    /// Get the last N turns
    public func getRecentTurns(count: Int) -> [ConversationTurn] {
        Array(turns.suffix(count))
    }

    // MARK: - Private Methods

    private func pruneTurns() {
        let now = Date()

        // Remove turns exceeding max count
        if turns.count > config.maxTurns {
            turns = Array(turns.suffix(config.maxTurns))
        }

        // Remove turns exceeding max age
        turns = turns.filter { turn in
            now.timeIntervalSince(turn.timestamp) < config.maxTurnAge
        }
    }

    private func extractTopics(from turn: ConversationTurn) {
        // Simple topic extraction based on nouns
        // In production, would use NLP or LLM
        let text = turn.originalText

        // Extract potential topics (simple keyword extraction)
        let keywords = extractKeywords(from: text)

        for keyword in keywords {
            if !extractedTopics.contains(keyword) {
                extractedTopics.append(keyword)

                // Keep only recent topics
                if extractedTopics.count > 10 {
                    extractedTopics.removeFirst()
                }
            }
        }
    }

    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction
        // In production, would use proper NLP
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }

        // Return words that might be topics (simplified)
        return Array(words.prefix(3))
    }

    private func trackEntities(from turn: ConversationTurn) {
        // Simple entity tracking
        // In production, would use NER

        let text = turn.originalText

        // Look for proper nouns (capitalized words in English, special patterns in Japanese)
        let patterns = [
            // Numbers with units
            "\\d+[万億千百]?[円個人名社]",
            // Quoted terms
            "「[^」]+」",
            "\"[^\"]+\""
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)

                for match in matches {
                    if let matchRange = Range(match.range, in: text) {
                        let entity = String(text[matchRange])
                        trackedEntities[entity] = "mentioned in conversation"
                    }
                }
            }
        }

        // Keep entity list manageable
        if trackedEntities.count > 20 {
            // Remove oldest entries (simple approach)
            let keysToRemove = Array(trackedEntities.keys.prefix(trackedEntities.count - 20))
            for key in keysToRemove {
                trackedEntities.removeValue(forKey: key)
            }
        }
    }

    private func learnSpeakerStyle(from turn: ConversationTurn) {
        let speaker = turn.speaker
        guard speaker != .unknown else { return }

        let text = turn.originalText

        // Analyze formality
        let formality = analyzeFormality(text)

        // Get or create speaker style
        var style = speakerStyles[speaker] ?? SpeakerStyle()

        // Update style based on new data
        style = SpeakerStyle(
            formality: formality,
            verbosity: analyzeVerbosity(text),
            preferredTerms: style.preferredTerms
        )

        speakerStyles[speaker] = style
    }

    private func analyzeFormality(_ text: String) -> SpeakerStyle.FormalityLevel {
        // Japanese formality markers
        let formalMarkers = ["です", "ます", "ございます", "いたします", "申します"]
        let casualMarkers = ["だよ", "だね", "じゃん", "っす", "わ"]

        var formalCount = 0
        var casualCount = 0

        for marker in formalMarkers {
            if text.contains(marker) { formalCount += 1 }
        }

        for marker in casualMarkers {
            if text.contains(marker) { casualCount += 1 }
        }

        if formalCount > casualCount + 1 {
            return .formal
        } else if casualCount > formalCount + 1 {
            return .casual
        }
        return .neutral
    }

    private func analyzeVerbosity(_ text: String) -> SpeakerStyle.VerbosityLevel {
        let wordCount = text.count // For Japanese, character count is more meaningful

        if wordCount < 20 {
            return .concise
        } else if wordCount > 100 {
            return .verbose
        }
        return .medium
    }

    private func findReferent(for demonstrative: String, in turns: [ConversationTurn]) -> (text: String, confidence: Float)? {
        guard !turns.isEmpty else { return nil }

        // Look at recent turns for potential referents
        let recentTurns = turns.suffix(3)

        // Simple heuristic: return the most recent noun phrase
        for turn in recentTurns.reversed() {
            let text = turn.originalText

            // Look for quoted content first
            if let range = text.range(of: "「[^」]+」", options: .regularExpression) {
                let content = String(text[range])
                return (content, 0.8)
            }

            // Otherwise use a portion of the text
            if text.count > 5 {
                return (String(text.prefix(20)), 0.5)
            }
        }

        return nil
    }
}

// MARK: - Reference Resolution Types

/// Result of reference resolution
public struct ResolvedText: Sendable {
    public let originalText: String
    public let resolvedText: String
    public let resolutions: [ReferenceResolution]

    public var hasResolutions: Bool {
        !resolutions.isEmpty
    }
}

/// A single reference resolution
public struct ReferenceResolution: Sendable {
    public let original: String
    public let resolved: String
    public let confidence: Float
    public let source: ReferenceSource

    public enum ReferenceSource: String, Sendable {
        case contextHistory
        case entityTracking
        case inference
    }
}
