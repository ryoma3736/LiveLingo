import XCTest
@testable import LiveLingo

final class EntityTests: XCTestCase {
    // MARK: - SupportedLanguage Tests

    func testSupportedLanguageProperties() {
        let japanese = SupportedLanguage.japanese

        XCTAssertEqual(japanese.rawValue, "ja-JP")
        XCTAssertEqual(japanese.nativeName, "日本語")
        XCTAssertEqual(japanese.languageCode, "ja")
        XCTAssertTrue(japanese.supportsOnDeviceTranslation)
    }

    func testSupportedLanguageAllCases() {
        XCTAssertEqual(SupportedLanguage.allCases.count, 8)
    }

    // MARK: - TranscriptItem Tests

    func testTranscriptItemCreation() {
        let item = TranscriptItem(
            speaker: .speaker1,
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            originalText: "こんにちは",
            translatedText: "Hello"
        )

        XCTAssertEqual(item.speaker, .speaker1)
        XCTAssertEqual(item.originalText, "こんにちは")
        XCTAssertEqual(item.translatedText, "Hello")
        XCTAssertTrue(item.isFinal)
    }

    // MARK: - RecognitionResult Tests

    func testRecognitionResultCreation() {
        let result = RecognitionResult(
            text: "Test speech",
            isFinal: true,
            speakerID: .speaker1,
            confidence: 0.95,
            language: .englishUS
        )

        XCTAssertEqual(result.text, "Test speech")
        XCTAssertTrue(result.isFinal)
        XCTAssertEqual(result.speakerID, .speaker1)
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.01)
    }

    // MARK: - TranslationResult Tests

    func testTranslationResultCreation() {
        let result = TranslationResult(
            originalText: "Hello",
            translatedText: "こんにちは",
            sourceLanguage: .englishUS,
            targetLanguage: .japanese,
            provider: .apple
        )

        XCTAssertEqual(result.originalText, "Hello")
        XCTAssertEqual(result.translatedText, "こんにちは")
        XCTAssertEqual(result.provider, .apple)
    }

    // MARK: - ConversationSession Tests

    func testConversationSessionCreation() {
        var session = ConversationSession(
            sourceLanguage: .japanese,
            targetLanguage: .englishUS
        )

        XCTAssertTrue(session.transcripts.isEmpty)
        XCTAssertEqual(session.sourceLanguage, .japanese)
        XCTAssertEqual(session.targetLanguage, .englishUS)

        // Add transcript
        let transcript = TranscriptItem(
            speaker: .speaker1,
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            originalText: "Test",
            translatedText: "Test"
        )
        session.addTranscript(transcript)

        XCTAssertEqual(session.transcripts.count, 1)
    }

    func testConversationSessionDisplayTitle() {
        let session = ConversationSession(
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            title: "My Conversation"
        )

        XCTAssertEqual(session.displayTitle, "My Conversation")
    }

    // MARK: - Glossary Tests

    func testGlossaryCreation() {
        var glossary = Glossary(
            name: "Business Terms",
            sourceLanguage: .englishUS,
            targetLanguage: .japanese
        )

        let entry = GlossaryEntry(
            sourceTerm: "meeting",
            targetTerm: "会議"
        )
        glossary.addEntry(entry)

        XCTAssertEqual(glossary.entries.count, 1)
        XCTAssertEqual(glossary.findTranslation(for: "meeting"), "会議")
    }

    // MARK: - VoiceOption Tests

    func testVoiceOptionCreation() {
        let voice = VoiceOption(
            id: "voice-1",
            name: "Default Japanese",
            language: .japanese,
            provider: .system,
            isDefault: true
        )

        XCTAssertEqual(voice.id, "voice-1")
        XCTAssertEqual(voice.language, .japanese)
        XCTAssertEqual(voice.provider, .system)
        XCTAssertTrue(voice.isDefault)
    }

    // MARK: - UserSettings Tests

    func testUserSettingsDefaults() {
        let settings = UserSettings()

        XCTAssertEqual(settings.preferredSourceLanguage, .japanese)
        XCTAssertEqual(settings.preferredTargetLanguage, .englishUS)
        XCTAssertTrue(settings.autoSaveEnabled)
        XCTAssertTrue(settings.iCloudSyncEnabled)
        XCTAssertEqual(settings.darkModePreference, .system)
    }
}
