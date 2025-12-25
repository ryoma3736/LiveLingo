import XCTest
@testable import LiveLingo

@MainActor
final class TTSServiceTests: XCTestCase {

    func testAppleTTSServiceInitialization() async throws {
        let service = AppleTTSService()
        XCTAssertEqual(service.provider, .system)
        XCTAssertFalse(service.isSpeaking)
    }

    func testAvailableVoicesForJapanese() async throws {
        let service = AppleTTSService()
        let voices = await service.availableVoices(for: .japanese)
        print("[TEST] Available Japanese voices: \(voices.count)")
        for voice in voices {
            print("[TEST]   - \(voice.name) (\(voice.id))")
        }
    }

    func testAvailableVoicesForEnglish() async throws {
        let service = AppleTTSService()
        let voices = await service.availableVoices(for: .englishUS)
        print("[TEST] Available English voices: \(voices.count)")
        XCTAssertGreaterThan(voices.count, 0, "Should have at least one English voice")
        for voice in voices {
            print("[TEST]   - \(voice.name) (\(voice.id))")
        }
    }

    func testDefaultVoiceForEnglish() async throws {
        let service = AppleTTSService()
        let voice = await service.defaultVoice(for: .englishUS)
        XCTAssertNotNil(voice, "Should have a default English voice")
        print("[TEST] Default English voice: \(voice?.name ?? "nil")")
    }

    func testSpeakDoesNotThrow() async throws {
        let service = AppleTTSService()
        guard let voice = await service.defaultVoice(for: .englishUS) else {
            XCTFail("No default voice available")
            return
        }

        // This should not throw - audio won't play in simulator but method should complete
        do {
            try await service.speak("Hello", voice: voice)
            print("[TEST] speak() completed successfully")
        } catch {
            XCTFail("speak() should not throw: \(error)")
        }
    }

    func testSpeakEmptyTextSkips() async throws {
        let service = AppleTTSService()
        guard let voice = await service.defaultVoice(for: .englishUS) else {
            XCTFail("No default voice available")
            return
        }

        // Empty text should return immediately without error
        try await service.speak("", voice: voice)
        try await service.speak("   ", voice: voice)
        print("[TEST] Empty text handling works correctly")
    }
}
