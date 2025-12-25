import XCTest
@testable import LiveLingo

final class GeminiLiveTests: XCTestCase {
    // MARK: - Configuration Tests

    func testGeminiLiveConfigWebSocketURL() {
        let config = GeminiLiveConfig(
            apiKey: "test-api-key",
            model: .gemini25FlashNativeAudio
        )

        let url = config.webSocketURL
        XCTAssertTrue(url.absoluteString.contains("generativelanguage.googleapis.com"))
        XCTAssertTrue(url.absoluteString.contains("test-api-key"))
        XCTAssertTrue(url.absoluteString.contains("wss://"))
    }

    func testGeminiModelRawValues() {
        XCTAssertEqual(GeminiModel.gemini25FlashNativeAudio.rawValue, "models/gemini-2.5-flash-native-audio-preview-12-2025")
        XCTAssertEqual(GeminiModel.gemini2FlashLive.rawValue, "models/gemini-2.0-flash-live-001")
        XCTAssertEqual(GeminiModel.gemini2FlashThinking.rawValue, "models/gemini-2.0-flash-thinking-exp")
    }

    func testResponseModalityRawValues() {
        XCTAssertEqual(ResponseModality.audio.rawValue, "AUDIO")
        XCTAssertEqual(ResponseModality.text.rawValue, "TEXT")
    }

    // MARK: - Audio Format Tests

    func testAudioFormatConstants() {
        XCTAssertEqual(GeminiAudioFormat.inputSampleRate, 16000)
        XCTAssertEqual(GeminiAudioFormat.inputBitsPerSample, 16)
        XCTAssertEqual(GeminiAudioFormat.inputChannels, 1)
        XCTAssertEqual(GeminiAudioFormat.outputSampleRate, 24000)
        XCTAssertEqual(GeminiAudioFormat.chunkSize, 1024)
        XCTAssertEqual(GeminiAudioFormat.inputMimeType, "audio/pcm;rate=16000")
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
        XCTAssertTrue(instruction.contains("Translate all speech"))
        XCTAssertFalse(instruction.contains("Detect the input language"))
    }

    // MARK: - Message Encoding Tests

    func testSetupMessageEncoding() throws {
        let setup = SetupConfig(
            model: "models/gemini-2.5-flash-native-audio-preview-12-2025",
            generationConfig: ClientGenerationConfig(
                responseModalities: ["AUDIO", "TEXT"]
            ),
            systemInstruction: SystemInstruction(text: "You are a translator")
        )

        let message = SetupMessage(setup: setup)

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("setup"))
        XCTAssertTrue(json.contains("gemini-2.5-flash-native-audio-preview-12-2025"))
        XCTAssertTrue(json.contains("responseModalities"))
    }

    func testRealtimeInputMessageEncoding() throws {
        let audioData = Data([0x00, 0x01, 0x02, 0x03])
        let base64 = audioData.base64EncodedString()

        let message = RealtimeInputMessage(
            realtimeInput: RealtimeInput(
                mediaChunks: [
                    MediaChunk(data: base64)
                ]
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("realtimeInput"))
        XCTAssertTrue(json.contains("mediaChunks"))
        XCTAssertTrue(json.contains("audio") && json.contains("pcm"))
    }

    func testClientContentMessageEncoding() throws {
        let message = ClientContentMessage(
            clientContent: ClientContent(
                turns: [
                    Turn(role: "user", parts: [ContentPart(text: "Hello")])
                ],
                turnComplete: true
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("clientContent"))
        XCTAssertTrue(json.contains("turnComplete"))
        XCTAssertTrue(json.contains("Hello"))
    }

    // MARK: - Message Decoding Tests

    func testSetupCompleteDecoding() throws {
        let json = """
        {"setupComplete": {}}
        """

        let decoder = JSONDecoder()
        let message = try decoder.decode(SetupCompleteMessage.self, from: json.data(using: .utf8)!)

        XCTAssertNotNil(message.setupComplete)
    }

    func testServerContentDecoding() throws {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        {"text": "Hello, how are you?"}
                    ]
                },
                "turnComplete": true
            }
        }
        """

        let decoder = JSONDecoder()
        let message = try decoder.decode(ServerContentMessage.self, from: json.data(using: .utf8)!)

        XCTAssertNotNil(message.serverContent.modelTurn)
        XCTAssertEqual(message.serverContent.modelTurn?.parts.first?.text, "Hello, how are you?")
        XCTAssertEqual(message.serverContent.turnComplete, true)
    }

    func testServerContentWithAudioDecoding() throws {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        {
                            "inlineData": {
                                "mimeType": "audio/pcm;rate=24000",
                                "data": "AAECBA=="
                            }
                        }
                    ]
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let message = try decoder.decode(ServerContentMessage.self, from: json.data(using: .utf8)!)

        let inlineData = message.serverContent.modelTurn?.parts.first?.inlineData
        XCTAssertNotNil(inlineData)
        XCTAssertTrue(inlineData?.mimeType.contains("audio") == true)
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

    func testGeminiLiveStateEquality() {
        XCTAssertEqual(GeminiLiveState.disconnected, GeminiLiveState.disconnected)
        XCTAssertEqual(GeminiLiveState.connecting, GeminiLiveState.connecting)
        XCTAssertEqual(GeminiLiveState.ready, GeminiLiveState.ready)
        XCTAssertNotEqual(GeminiLiveState.disconnected, GeminiLiveState.connected)

        XCTAssertEqual(
            GeminiLiveState.error("test"),
            GeminiLiveState.error("test")
        )
        XCTAssertNotEqual(
            GeminiLiveState.error("test1"),
            GeminiLiveState.error("test2")
        )
    }

    // MARK: - Speech Config Tests

    func testSpeechConfigEncoding() throws {
        let voiceConfig = VoiceConfig(
            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Aoede")
        )
        let speechConfig = SpeechConfig(voiceConfig: voiceConfig)

        let encoder = JSONEncoder()
        let data = try encoder.encode(speechConfig)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("voiceConfig"))
        XCTAssertTrue(json.contains("prebuiltVoiceConfig"))
        XCTAssertTrue(json.contains("Aoede"))
    }
}

// MARK: - Live Translation State Tests

final class LiveTranslationStateTests: XCTestCase {
    func testLiveTranslationStateValues() {
        let states: [LiveTranslationState] = [
            .inactive,
            .connecting,
            .active,
            .processing,
            .error
        ]

        XCTAssertEqual(states.count, 5)
    }
}
