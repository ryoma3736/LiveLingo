import XCTest
@testable import LiveLingo

// MARK: - Full Integration Tests

final class IntegrationTests: XCTestCase {
    // MARK: - Translation Flow Tests

    func testTranslationFlowWithMockServices() async throws {
        let sttService = MockSTTService()
        let translationService = MockTranslationService()
        let ttsService = MockTTSService()

        // Start recognition
        let stream = try await sttService.startRecognition(language: .japanese)

        var recognitionResults: [RecognitionResult] = []
        for await result in stream {
            recognitionResults.append(result)
            if recognitionResults.count >= 1 {
                break
            }
        }

        XCTAssertFalse(recognitionResults.isEmpty)

        // Translate the recognized text
        if let firstResult = recognitionResults.first {
            let translationResult = try await translationService.translate(
                firstResult.text,
                from: .japanese,
                to: .englishUS
            )

            XCTAssertEqual(translationResult.sourceLanguage, .japanese)
            XCTAssertEqual(translationResult.targetLanguage, .englishUS)
            XCTAssertFalse(translationResult.translatedText.isEmpty)

            // Get voice for TTS
            let voices = await ttsService.availableVoices(for: .englishUS)
            XCTAssertFalse(voices.isEmpty)
        }
    }

    func testConversationSessionFlow() async throws {
        let repository = MockConversationRepository()

        // Create new session
        var session = ConversationSession(
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            title: "Test Session"
        )

        // Add transcripts
        let transcript1 = TranscriptItem(
            speaker: .speaker1,
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            originalText: "こんにちは",
            translatedText: "Hello"
        )
        session.addTranscript(transcript1)

        let transcript2 = TranscriptItem(
            speaker: .speaker2,
            sourceLanguage: .englishUS,
            targetLanguage: .japanese,
            originalText: "Hello, how are you?",
            translatedText: "こんにちは、お元気ですか？"
        )
        session.addTranscript(transcript2)

        // Save session
        try await repository.save(session)

        // Retrieve and verify
        let retrieved = try await repository.get(id: session.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.transcripts.count, 2)
        XCTAssertEqual(retrieved?.displayTitle, "Test Session")
    }

    // MARK: - Settings Flow Tests

    func testSettingsFlow() async throws {
        let repository = MockSettingsRepository()

        // Get default settings
        var settings = await repository.getSettings()
        XCTAssertEqual(settings.preferredSourceLanguage, .japanese)
        XCTAssertEqual(settings.preferredTargetLanguage, .englishUS)

        // Modify settings
        settings.preferredSourceLanguage = .englishUS
        settings.preferredTargetLanguage = .japanese
        try await repository.saveSettings(settings)

        // Verify changes persisted
        let updatedSettings = await repository.getSettings()
        XCTAssertEqual(updatedSettings.preferredSourceLanguage, .englishUS)
        XCTAssertEqual(updatedSettings.preferredTargetLanguage, .japanese)

        // Reset to defaults
        await repository.resetToDefaults()
        let resetSettings = await repository.getSettings()
        XCTAssertEqual(resetSettings.preferredSourceLanguage, .japanese)
    }

    // MARK: - Glossary Flow Tests

    func testGlossaryFlow() async throws {
        let repository = MockGlossaryRepository()

        // Create glossary
        var glossary = Glossary(
            name: "Business Terms",
            sourceLanguage: .englishUS,
            targetLanguage: .japanese
        )

        // Add entries
        glossary.addEntry(GlossaryEntry(sourceTerm: "meeting", targetTerm: "会議"))
        glossary.addEntry(GlossaryEntry(sourceTerm: "deadline", targetTerm: "締め切り"))
        glossary.addEntry(GlossaryEntry(sourceTerm: "report", targetTerm: "報告書"))

        // Save and retrieve
        try await repository.save(glossary)

        let retrieved = try await repository.get(id: glossary.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.entries.count, 3)

        // Test translation lookup
        XCTAssertEqual(retrieved?.findTranslation(for: "meeting"), "会議")
        XCTAssertEqual(retrieved?.findTranslation(for: "deadline"), "締め切り")
        XCTAssertNil(retrieved?.findTranslation(for: "unknown"))
    }

    // MARK: - Error Handling Tests

    func testErrorRecovery() async throws {
        // Test error creation and messages
        let errors: [LiveLingoError] = [
            .sttNotAvailable(reason: "Test reason"),
            .sttPermissionDenied,
            .translationProviderUnavailable(.openAI),
            .networkUnavailable,
            .permissionDenied(permission: .microphone)
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
        }
    }

    // MARK: - Language Support Tests

    func testAllLanguagesHaveRequiredProperties() {
        for language in SupportedLanguage.allCases {
            XCTAssertFalse(language.rawValue.isEmpty)
            XCTAssertFalse(language.nativeName.isEmpty)
            XCTAssertFalse(language.localizedName.isEmpty)
            XCTAssertFalse(language.flagEmoji.isEmpty)
            XCTAssertFalse(language.languageCode.isEmpty)
            XCTAssertNotNil(language.locale)
        }
    }

    func testLanguagePairsForTranslation() async {
        let translationService = MockTranslationService()

        // Test that all language pairs are available
        let pairs: [(SupportedLanguage, SupportedLanguage)] = [
            (.japanese, .englishUS),
            (.englishUS, .japanese),
            (.chineseSimplified, .englishUS),
            (.korean, .japanese)
        ]

        for (source, target) in pairs {
            let isAvailable = await translationService.isAvailable(from: source, to: target)
            XCTAssertTrue(isAvailable, "Translation should be available from \(source) to \(target)")
        }
    }
}

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {
    func testTranscriptListPerformance() {
        // Test performance with many transcripts
        var session = ConversationSession(
            sourceLanguage: .japanese,
            targetLanguage: .englishUS
        )

        measure {
            for i in 0..<1000 {
                let transcript = TranscriptItem(
                    speaker: i % 2 == 0 ? .speaker1 : .speaker2,
                    sourceLanguage: .japanese,
                    targetLanguage: .englishUS,
                    originalText: "Test message \(i)",
                    translatedText: "Translated message \(i)"
                )
                session.addTranscript(transcript)
            }
        }

        XCTAssertEqual(session.transcripts.count, 1000)
    }

    func testTranslationCachePerformance() async {
        let cache = TranslationCache(maxSize: 10000)

        // Fill cache
        for i in 0..<1000 {
            let result = TranslationResult(
                originalText: "Text \(i)",
                translatedText: "Translated \(i)",
                sourceLanguage: .japanese,
                targetLanguage: .englishUS,
                provider: .apple
            )
            await cache.set(result)
        }

        // Measure lookup performance
        let start = CFAbsoluteTimeGetCurrent()
        for i in 0..<100 {
            let _ = await cache.get(text: "Text \(i)", from: .japanese, to: .englishUS)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertLessThan(elapsed, 1.0, "Cache lookups should be fast")
    }
}

// MARK: - Concurrent Access Tests

final class ConcurrencyTests: XCTestCase {
    func testConcurrentRepositoryAccess() async throws {
        let repository = MockConversationRepository()

        // Create multiple sessions concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let session = ConversationSession(
                        sourceLanguage: .japanese,
                        targetLanguage: .englishUS,
                        title: "Session \(i)"
                    )
                    try? await repository.save(session)
                }
            }
        }

        let sessions = try await repository.getAll()
        // Should have original sample + 10 new sessions
        XCTAssertGreaterThanOrEqual(sessions.count, 10)
    }

    func testConcurrentCacheAccess() async {
        let cache = TranslationCache()

        // Concurrent reads and writes
        await withTaskGroup(of: Void.self) { group in
            // Writers
            for i in 0..<50 {
                group.addTask {
                    let result = TranslationResult(
                        originalText: "Text \(i)",
                        translatedText: "Translated \(i)",
                        sourceLanguage: .japanese,
                        targetLanguage: .englishUS,
                        provider: .apple
                    )
                    await cache.set(result)
                }
            }

            // Readers
            for i in 0..<50 {
                group.addTask {
                    let _ = await cache.get(text: "Text \(i)", from: .japanese, to: .englishUS)
                }
            }
        }

        // Should complete without deadlock
        XCTAssertTrue(true)
    }
}
