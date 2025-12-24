import XCTest
@testable import LiveLingo

final class MockServiceTests: XCTestCase {
    // MARK: - Mock STT Service Tests

    func testMockSTTServiceStartRecognition() async throws {
        let stt = MockSTTService()

        let stream = try await stt.startRecognition(language: .japanese)
        var results: [RecognitionResult] = []

        for await result in stream {
            results.append(result)
            if results.count >= 1 {
                break // Get at least one result
            }
        }

        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.first?.language, .japanese)
    }

    func testMockSTTServiceAvailability() async {
        let stt = MockSTTService()

        let isAvailable = await stt.isAvailable
        XCTAssertTrue(isAvailable)

        let languages = await stt.supportedLanguages
        XCTAssertEqual(languages.count, SupportedLanguage.allCases.count)
    }

    // MARK: - Mock Translation Service Tests

    func testMockTranslationService() async throws {
        let translation = MockTranslationService()

        let result = try await translation.translate(
            "こんにちは",
            from: .japanese,
            to: .englishUS
        )

        XCTAssertEqual(result.originalText, "こんにちは")
        XCTAssertEqual(result.translatedText, "Hello")
        XCTAssertEqual(result.sourceLanguage, .japanese)
        XCTAssertEqual(result.targetLanguage, .englishUS)
    }

    func testMockTranslationServiceAvailability() async {
        let translation = MockTranslationService()

        let isAvailable = await translation.isAvailable(from: .japanese, to: .englishUS)
        XCTAssertTrue(isAvailable)
    }

    // MARK: - Mock TTS Service Tests

    func testMockTTSServiceSynthesize() async throws {
        let tts = MockTTSService()

        let voice = VoiceOption(
            id: "test-voice",
            name: "Test",
            language: .japanese,
            provider: .system
        )

        let data = try await tts.synthesize("こんにちは", voice: voice)
        XCTAssertNotNil(data)
    }

    func testMockTTSServiceAvailableVoices() async {
        let tts = MockTTSService()

        let voices = await tts.availableVoices(for: .japanese)
        XCTAssertFalse(voices.isEmpty)
        XCTAssertEqual(voices.first?.language, .japanese)
    }

    // MARK: - Mock Conversation Repository Tests

    func testMockConversationRepository() async throws {
        let repo = MockConversationRepository()

        // Get all sessions
        let sessions = try await repo.getAll()
        XCTAssertFalse(sessions.isEmpty)

        // Save a new session
        let newSession = ConversationSession(
            sourceLanguage: .englishUS,
            targetLanguage: .japanese
        )
        try await repo.save(newSession)

        let updatedSessions = try await repo.getAll()
        XCTAssertEqual(updatedSessions.count, sessions.count + 1)

        // Delete the session
        try await repo.delete(id: newSession.id)
        let finalSessions = try await repo.getAll()
        XCTAssertEqual(finalSessions.count, sessions.count)
    }

    // MARK: - Mock Settings Repository Tests

    func testMockSettingsRepository() async throws {
        let repo = MockSettingsRepository()

        var settings = await repo.getSettings()
        XCTAssertEqual(settings.preferredSourceLanguage, .japanese)

        settings.preferredSourceLanguage = .englishUS
        try await repo.saveSettings(settings)

        let updatedSettings = await repo.getSettings()
        XCTAssertEqual(updatedSettings.preferredSourceLanguage, .englishUS)

        await repo.resetToDefaults()
        let resetSettings = await repo.getSettings()
        XCTAssertEqual(resetSettings.preferredSourceLanguage, .japanese)
    }

    // MARK: - Mock Glossary Repository Tests

    func testMockGlossaryRepository() async throws {
        let repo = MockGlossaryRepository()

        let glossary = Glossary(
            name: "Test Glossary",
            sourceLanguage: .englishUS,
            targetLanguage: .japanese,
            entries: [
                GlossaryEntry(sourceTerm: "hello", targetTerm: "こんにちは")
            ]
        )

        try await repo.save(glossary)

        let glossaries = try await repo.getAll()
        XCTAssertEqual(glossaries.count, 1)

        let retrieved = try await repo.get(id: glossary.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test Glossary")
    }
}
