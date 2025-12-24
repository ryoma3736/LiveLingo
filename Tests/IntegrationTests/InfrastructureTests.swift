import XCTest
@testable import LiveLingo

final class InfrastructureTests: XCTestCase {
    // MARK: - Network Client Tests

    func testNetworkRequestCreation() {
        let getRequest = NetworkRequest.get("/api/translate", queryItems: [
            URLQueryItem(name: "text", value: "Hello")
        ])

        XCTAssertEqual(getRequest.method, .get)
        XCTAssertEqual(getRequest.path, "/api/translate")
        XCTAssertEqual(getRequest.queryItems?.count, 1)
    }

    func testNetworkRequestWithBody() throws {
        struct TestBody: Encodable {
            let text: String
            let language: String
        }

        let body = TestBody(text: "Hello", language: "ja-JP")
        let request = try NetworkRequest.post("/api/translate", body: body)

        XCTAssertEqual(request.method, .post)
        XCTAssertNotNil(request.body)
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
    }

    func testNetworkConfiguration() {
        let defaultConfig = NetworkConfiguration.default

        XCTAssertEqual(defaultConfig.timeoutInterval, 30)
        XCTAssertEqual(defaultConfig.maxRetries, 3)
    }

    // MARK: - Keychain Tests

    func testKeychainKeyValues() {
        XCTAssertEqual(KeychainKey.openAIAPIKey.rawValue, "com.livelingo.openai-api-key")
        XCTAssertEqual(KeychainKey.anthropicAPIKey.rawValue, "com.livelingo.anthropic-api-key")
        XCTAssertEqual(KeychainKey.coeFontAPIKey.rawValue, "com.livelingo.coefont-api-key")
    }

    func testKeychainErrorDescriptions() {
        let error1 = KeychainError.itemNotFound
        XCTAssertTrue(error1.errorDescription?.contains("not found") == true)

        let error2 = KeychainError.duplicateItem
        XCTAssertTrue(error2.errorDescription?.contains("already exists") == true)
    }

    // MARK: - Audio Session Tests

    func testAudioSessionModeProperties() {
        let recordingMode = AudioSessionMode.recording
        XCTAssertNotNil(recordingMode.category)
        XCTAssertNotNil(recordingMode.mode)

        let conversationMode = AudioSessionMode.conversation
        XCTAssertNotNil(conversationMode.category)
    }

    func testAudioRouteCreation() {
        let route = AudioRoute(
            id: "test-route",
            name: "Test Speaker",
            type: .builtInSpeaker,
            isActive: true
        )

        XCTAssertEqual(route.id, "test-route")
        XCTAssertEqual(route.name, "Test Speaker")
        XCTAssertEqual(route.type, .builtInSpeaker)
        XCTAssertTrue(route.isActive)
    }

    // MARK: - Permission Tests

    func testPermissionRequirements() {
        let requirements = PermissionRequirement.allRequired

        XCTAssertEqual(requirements.count, 3)
        XCTAssertTrue(requirements.contains { $0.permission == .microphone && $0.isRequired })
        XCTAssertTrue(requirements.contains { $0.permission == .speechRecognition && $0.isRequired })
        XCTAssertTrue(requirements.contains { $0.permission == .notifications && !$0.isRequired })
    }

    func testPermissionCheckResult() {
        let result = PermissionCheckResult(statuses: [
            .microphone: .authorized,
            .speechRecognition: .authorized,
            .notifications: .denied
        ])

        XCTAssertTrue(result.requiredGranted)
        XCTAssertFalse(result.allGranted)
        XCTAssertEqual(result.deniedPermissions, [.notifications])
    }
}

// MARK: - Service Tests

final class ServiceTests: XCTestCase {
    // MARK: - Translation Tests

    func testTranslationDomainValues() {
        XCTAssertEqual(TranslationDomain.general.rawValue, "general")
        XCTAssertEqual(TranslationDomain.business.rawValue, "business")
        XCTAssertEqual(TranslationDomain.medical.rawValue, "medical")
    }

    func testTranslationContext() {
        let context = TranslationContext(
            domain: .business,
            glossary: nil,
            previousTranslations: []
        )

        XCTAssertEqual(context.domain, .business)
        XCTAssertNil(context.glossary)
        XCTAssertTrue(context.previousTranslations.isEmpty)
    }

    // MARK: - Voice Tests

    func testVoiceQualityDisplayNames() {
        XCTAssertEqual(VoiceQuality.standard.displayName, "Standard")
        XCTAssertEqual(VoiceQuality.enhanced.displayName, "Enhanced")
        XCTAssertEqual(VoiceQuality.premium.displayName, "Premium")
    }

    func testVoiceGenderDisplayNames() {
        XCTAssertEqual(VoiceGender.male.displayName, "Male")
        XCTAssertEqual(VoiceGender.female.displayName, "Female")
    }
}

// MARK: - Translation Cache Tests

final class TranslationCacheTests: XCTestCase {
    func testCacheSetAndGet() async {
        let cache = TranslationCache(maxSize: 10, ttl: 3600)

        let result = TranslationResult(
            originalText: "Hello",
            translatedText: "こんにちは",
            sourceLanguage: .englishUS,
            targetLanguage: .japanese,
            provider: .apple,
            confidence: 0.9
        )

        await cache.set(result)

        let cached = await cache.get(text: "Hello", from: .englishUS, to: .japanese)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.translatedText, "こんにちは")
    }

    func testCacheMiss() async {
        let cache = TranslationCache()

        let result = await cache.get(text: "Unknown", from: .englishUS, to: .japanese)
        XCTAssertNil(result)
    }

    func testCacheClear() async {
        let cache = TranslationCache()

        let result = TranslationResult(
            originalText: "Test",
            translatedText: "テスト",
            sourceLanguage: .englishUS,
            targetLanguage: .japanese,
            provider: .apple
        )

        await cache.set(result)
        await cache.clear()

        let cached = await cache.get(text: "Test", from: .englishUS, to: .japanese)
        XCTAssertNil(cached)
    }
}
