import XCTest
@testable import LiveLingo

/// Tests for streaming translation functionality
final class StreamingTranslationTests: XCTestCase {

    // MARK: - Gemini Live Config Tests

    func testGeminiLiveConfigWebSocketURL() {
        let config = GeminiLiveConfig(
            apiKey: "test-api-key",
            model: .gemini2FlashLive
        )

        let url = config.webSocketURL
        XCTAssertTrue(url.absoluteString.contains("v1alpha"))
        XCTAssertTrue(url.absoluteString.contains("BidiGenerateContent"))
        XCTAssertTrue(url.absoluteString.contains("test-api-key"))
    }

    func testGeminiModelRawValues() {
        XCTAssertEqual(
            GeminiModel.gemini2FlashLive.rawValue,
            "models/gemini-2.0-flash-live-001"
        )
        XCTAssertEqual(
            GeminiModel.gemini25FlashNativeAudio.rawValue,
            "models/gemini-2.5-flash-preview-native-audio-dialog"
        )
    }

    // MARK: - Translation Mode Tests

    func testTranslationModeSystemInstruction() {
        let mode = TranslationMode(
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            bidirectional: true
        )

        let instruction = mode.systemInstruction
        XCTAssertTrue(instruction.contains("Japanese"))
        XCTAssertTrue(instruction.contains("English"))
        XCTAssertTrue(instruction.contains("interpreter"))
    }

    func testTranslationModeUnidirectional() {
        let mode = TranslationMode(
            sourceLanguage: .japanese,
            targetLanguage: .englishUS,
            bidirectional: false
        )

        let instruction = mode.systemInstruction
        XCTAssertFalse(instruction.contains("Detect the input language"))
    }

    // MARK: - Audio Format Tests

    func testGeminiAudioFormatConstants() {
        XCTAssertEqual(GeminiAudioFormat.inputSampleRate, 16000)
        XCTAssertEqual(GeminiAudioFormat.inputBitsPerSample, 16)
        XCTAssertEqual(GeminiAudioFormat.inputChannels, 1)
        XCTAssertEqual(GeminiAudioFormat.outputSampleRate, 24000)
        XCTAssertEqual(GeminiAudioFormat.inputMimeType, "audio/pcm;rate=16000")
    }

    // MARK: - Message Encoding Tests

    func testRealtimeInputMessageEncoding() throws {
        let chunk = MediaChunk(
            mimeType: "audio/pcm;rate=16000",
            data: "base64encodedaudio"
        )
        let input = RealtimeInput(mediaChunks: [chunk])
        let message = RealtimeInputMessage(realtimeInput: input)

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("realtime_input"))
        XCTAssertTrue(json.contains("media_chunks"))
        XCTAssertTrue(json.contains("mime_type"))
    }

    func testSetupMessageEncoding() throws {
        let voiceConfig = VoiceConfig(
            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Aoede")
        )
        let speechConfig = SpeechConfig(voiceConfig: voiceConfig)
        let genConfig = ClientGenerationConfig(
            responseModalities: ["AUDIO", "TEXT"],
            speechConfig: speechConfig
        )
        let setup = SetupConfig(
            model: "models/gemini-2.0-flash-live-001",
            generationConfig: genConfig,
            systemInstruction: SystemInstruction(text: "You are a translator"),
            tools: nil
        )
        let message = SetupMessage(setup: setup)

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("setup"))
        XCTAssertTrue(json.contains("generation_config"))
        XCTAssertTrue(json.contains("response_modalities"))
        XCTAssertTrue(json.contains("voice_name"))
        XCTAssertTrue(json.contains("Aoede"))
    }

    // MARK: - Server Message Decoding Tests

    func testSetupCompleteMessageDecoding() throws {
        let json = """
        {"setupComplete": {}}
        """

        let decoder = JSONDecoder()
        let message = try decoder.decode(SetupCompleteMessage.self, from: json.data(using: .utf8)!)

        XCTAssertNotNil(message.setupComplete)
    }

    func testServerContentMessageDecoding() throws {
        let json = """
        {
            "serverContent": {
                "model_turn": {
                    "parts": [
                        {"text": "Hello, how are you?"}
                    ]
                },
                "turn_complete": true
            }
        }
        """

        let decoder = JSONDecoder()
        let message = try decoder.decode(ServerContentMessage.self, from: json.data(using: .utf8)!)

        XCTAssertNotNil(message.serverContent.modelTurn)
        XCTAssertEqual(message.serverContent.modelTurn?.parts.first?.text, "Hello, how are you?")
        XCTAssertTrue(message.serverContent.turnComplete ?? false)
    }

    func testErrorMessageDecoding() throws {
        let json = """
        {
            "error": {
                "code": 400,
                "message": "Invalid request",
                "status": "INVALID_ARGUMENT"
            }
        }
        """

        let decoder = JSONDecoder()
        let message = try decoder.decode(ErrorMessage.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(message.error.code, 400)
        XCTAssertEqual(message.error.message, "Invalid request")
        XCTAssertEqual(message.error.status, "INVALID_ARGUMENT")
    }

    // MARK: - State Tests

    func testGeminiLiveStateEquatable() {
        XCTAssertEqual(GeminiLiveState.disconnected, GeminiLiveState.disconnected)
        XCTAssertEqual(GeminiLiveState.connected, GeminiLiveState.connected)
        XCTAssertEqual(GeminiLiveState.error("Test"), GeminiLiveState.error("Test"))
        XCTAssertNotEqual(GeminiLiveState.error("A"), GeminiLiveState.error("B"))
    }
}

// MARK: - Wait-K Translator Tests

final class WaitKTranslatorTests: XCTestCase {

    func testStreamingTranslationConfigDefaults() {
        let config = StreamingTranslationConfig()

        XCTAssertEqual(config.waitK, 3)
        XCTAssertEqual(config.flushInterval, 0.5)
        XCTAssertTrue(config.adaptiveK)
    }

    func testStreamingTranslationConfigCustom() {
        let config = StreamingTranslationConfig(
            waitK: 5,
            flushInterval: 1.0,
            adaptiveK: false
        )

        XCTAssertEqual(config.waitK, 5)
        XCTAssertEqual(config.flushInterval, 1.0)
        XCTAssertFalse(config.adaptiveK)
    }
}

// MARK: - Performance Tests

final class PerformanceTests: XCTestCase {

    func testPerformanceMonitorTimer() async {
        let monitor = PerformanceMonitor.shared
        await monitor.reset()

        await monitor.startTimer("test.operation")
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        let duration = await monitor.stopTimer("test.operation")

        XCTAssertNotNil(duration)
        XCTAssertGreaterThanOrEqual(duration!, 0.09)
        XCTAssertLessThanOrEqual(duration!, 0.2)
    }

    func testPerformanceMetricStatistics() async {
        let monitor = PerformanceMonitor.shared
        await monitor.reset()

        // Record multiple samples
        for i in 1...10 {
            await monitor.recordMetric(name: "test.metric", value: Double(i) * 0.01)
        }

        let stats = await monitor.getStatistics(for: "test.metric")
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.sampleCount, 10)
        XCTAssertEqual(stats?.min, 0.01, accuracy: 0.001)
        XCTAssertEqual(stats?.max, 0.10, accuracy: 0.001)
        XCTAssertEqual(stats?.average, 0.055, accuracy: 0.001)
    }

    func testStreamingMetricPresets() async {
        let monitor = PerformanceMonitor.shared
        await monitor.reset()

        await monitor.start(.translationRoundTrip)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        let duration = await monitor.stop(.translationRoundTrip)

        XCTAssertNotNil(duration)

        let stats = await monitor.statistics(for: .translationRoundTrip)
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.sampleCount, 1)
    }
}
