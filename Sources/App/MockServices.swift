import Foundation

// MARK: - Mock STT Service

/// Mock STT service for testing and previews
public actor MockSTTService: STTServiceProtocol {
    public var isAvailable: Bool = true
    public var isRecognizing: Bool = false
    public var supportedLanguages: [SupportedLanguage] = SupportedLanguage.allCases

    public init() {}

    public func startRecognition(language: SupportedLanguage) async throws -> AsyncStream<RecognitionResult> {
        isRecognizing = true
        return AsyncStream { continuation in
            Task {
                // Simulate recognition results
                let samples = [
                    "こんにちは",
                    "今日はいい天気ですね",
                    "お元気ですか"
                ]

                for sample in samples {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    continuation.yield(RecognitionResult(
                        text: sample,
                        isFinal: true,
                        speakerID: .speaker1,
                        confidence: 0.95,
                        language: language
                    ))
                }

                continuation.finish()
            }
        }
    }

    public func stopRecognition() async {
        isRecognizing = false
    }
}

// MARK: - Mock Translation Service

/// Mock translation service for testing and previews
public actor MockTranslationService: TranslationServiceProtocol {
    public let provider: TranslationProvider = .apple

    public init() {}

    public func translate(_ text: String, from: SupportedLanguage, to: SupportedLanguage) async throws -> TranslationResult {
        // Simulate translation delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let translated: String
        if from == .japanese && to == .englishUS {
            translated = mockJapaneseToEnglish(text)
        } else {
            translated = "[Translated] \(text)"
        }

        return TranslationResult(
            originalText: text,
            translatedText: translated,
            sourceLanguage: from,
            targetLanguage: to,
            provider: .apple,
            confidence: 0.9
        )
    }

    public func streamTranslate(_ text: String, from: SupportedLanguage, to: SupportedLanguage) async -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let result = try? await self.translate(text, from: from, to: to)
                if let translated = result?.translatedText {
                    continuation.yield(translated)
                }
                continuation.finish()
            }
        }
    }

    public func isAvailable(from: SupportedLanguage, to: SupportedLanguage) async -> Bool {
        return true
    }

    private func mockJapaneseToEnglish(_ text: String) -> String {
        let translations: [String: String] = [
            "こんにちは": "Hello",
            "今日はいい天気ですね": "It's nice weather today",
            "お元気ですか": "How are you?"
        ]
        return translations[text] ?? "[Translated] \(text)"
    }
}

// MARK: - Mock TTS Service

/// Mock TTS service for testing and previews
public actor MockTTSService: TTSServiceProtocol {
    public let provider: VoiceProvider = .system
    public var isSpeaking: Bool = false

    public init() {}

    public func synthesize(_ text: String, voice: VoiceOption) async throws -> Data {
        // Return empty audio data for mock
        return Data()
    }

    public func streamSynthesize(_ text: String, voice: VoiceOption) async -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(Data())
            continuation.finish()
        }
    }

    public func play(_ data: Data) async throws {
        isSpeaking = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isSpeaking = false
    }

    public func speak(_ text: String, voice: VoiceOption) async throws {
        isSpeaking = true
        // Simulate speaking time based on text length
        let duration = UInt64(max(500_000_000, text.count * 50_000_000))
        try? await Task.sleep(nanoseconds: duration)
        isSpeaking = false
    }

    public func defaultVoice(for language: SupportedLanguage) async -> VoiceOption? {
        return VoiceOption(
            id: "mock-default-\(language.languageCode)",
            name: "Mock Default Voice",
            language: language,
            provider: .system,
            isDefault: true
        )
    }

    public func stopPlayback() async {
        isSpeaking = false
    }

    public func availableVoices(for language: SupportedLanguage) async -> [VoiceOption] {
        return [
            VoiceOption(
                id: "mock-voice-\(language.languageCode)",
                name: "Mock Voice",
                language: language,
                provider: .system,
                isDefault: true
            )
        ]
    }
}

// MARK: - Mock Repositories

/// Mock conversation repository
public actor MockConversationRepository: ConversationRepositoryProtocol {
    private var sessions: [ConversationSession] = []

    public init() {
        // Add sample data
        sessions = [
            ConversationSession(
                sourceLanguage: .japanese,
                targetLanguage: .englishUS,
                transcripts: [
                    TranscriptItem(
                        speaker: .speaker1,
                        sourceLanguage: .japanese,
                        targetLanguage: .englishUS,
                        originalText: "こんにちは",
                        translatedText: "Hello"
                    )
                ],
                title: "Sample Conversation"
            )
        ]
    }

    public func save(_ session: ConversationSession) async throws {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    public func getAll() async throws -> [ConversationSession] {
        return sessions
    }

    public func get(id: UUID) async throws -> ConversationSession? {
        return sessions.first { $0.id == id }
    }

    public func delete(id: UUID) async throws {
        sessions.removeAll { $0.id == id }
    }

    public func search(query: String) async throws -> [ConversationSession] {
        return sessions.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query)
        }
    }

    public func getRecent(limit: Int) async throws -> [ConversationSession] {
        return Array(sessions.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    public func export(_ session: ConversationSession, format: ExportFormat) async throws -> Data {
        return Data()
    }
}

/// Mock settings repository
public actor MockSettingsRepository: SettingsRepositoryProtocol {
    private var settings = UserSettings()

    public init() {}

    public func getSettings() async -> UserSettings {
        return settings
    }

    public func saveSettings(_ settings: UserSettings) async throws {
        self.settings = settings
    }

    public func resetToDefaults() async {
        settings = UserSettings()
    }
}

/// Mock glossary repository
public actor MockGlossaryRepository: GlossaryRepositoryProtocol {
    private var glossaries: [Glossary] = []

    public init() {}

    public func save(_ glossary: Glossary) async throws {
        if let index = glossaries.firstIndex(where: { $0.id == glossary.id }) {
            glossaries[index] = glossary
        } else {
            glossaries.append(glossary)
        }
    }

    public func getAll() async throws -> [Glossary] {
        return glossaries
    }

    public func get(id: UUID) async throws -> Glossary? {
        return glossaries.first { $0.id == id }
    }

    public func delete(id: UUID) async throws {
        glossaries.removeAll { $0.id == id }
    }

    public func getActive(for sourceLanguage: SupportedLanguage, to targetLanguage: SupportedLanguage) async throws -> [Glossary] {
        return glossaries.filter {
            $0.isActive && $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage
        }
    }

    public func importGlossary(from data: Data, format: GlossaryFormat) async throws -> Glossary {
        return Glossary(name: "Imported", sourceLanguage: .japanese, targetLanguage: .englishUS)
    }

    public func exportGlossary(_ glossary: Glossary, format: GlossaryFormat) async throws -> Data {
        return Data()
    }
}
