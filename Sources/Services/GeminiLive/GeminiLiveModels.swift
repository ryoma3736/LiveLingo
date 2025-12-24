import Foundation

// MARK: - Gemini Live API Configuration

/// Configuration for Gemini Live API connection
public struct GeminiLiveConfig: Sendable {
    public let apiKey: String
    public let model: GeminiModel
    public let systemInstruction: String?
    public let responseModalities: [ResponseModality]
    public let speechConfig: SpeechConfig?
    public let generationConfig: GenerationConfig?

    public init(
        apiKey: String,
        model: GeminiModel = .gemini2FlashLive,
        systemInstruction: String? = nil,
        responseModalities: [ResponseModality] = [.audio],
        speechConfig: SpeechConfig? = nil,
        generationConfig: GenerationConfig? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.systemInstruction = systemInstruction
        self.responseModalities = responseModalities
        self.speechConfig = speechConfig
        self.generationConfig = generationConfig
    }

    /// WebSocket URL for Gemini Live API
    public var webSocketURL: URL {
        URL(string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)")!
    }
}

// MARK: - Models

public enum GeminiModel: String, Sendable {
    case gemini2FlashLive = "models/gemini-2.0-flash-exp"
    case gemini2FlashThinking = "models/gemini-2.0-flash-thinking-exp"
}

public enum ResponseModality: String, Codable, Sendable {
    case audio = "AUDIO"
    case text = "TEXT"
}

// MARK: - Speech Configuration

public struct SpeechConfig: Codable, Sendable {
    public let voiceConfig: VoiceConfig?

    public init(voiceConfig: VoiceConfig? = nil) {
        self.voiceConfig = voiceConfig
    }

    enum CodingKeys: String, CodingKey {
        case voiceConfig = "voice_config"
    }
}

public struct VoiceConfig: Codable, Sendable {
    public let prebuiltVoiceConfig: PrebuiltVoiceConfig?

    public init(prebuiltVoiceConfig: PrebuiltVoiceConfig?) {
        self.prebuiltVoiceConfig = prebuiltVoiceConfig
    }

    enum CodingKeys: String, CodingKey {
        case prebuiltVoiceConfig = "prebuilt_voice_config"
    }
}

public struct PrebuiltVoiceConfig: Codable, Sendable {
    public let voiceName: String

    public init(voiceName: String) {
        self.voiceName = voiceName
    }

    enum CodingKeys: String, CodingKey {
        case voiceName = "voice_name"
    }
}

// MARK: - Generation Configuration

public struct GenerationConfig: Codable, Sendable {
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let maxOutputTokens: Int?

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxOutputTokens = maxOutputTokens
    }

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case maxOutputTokens = "max_output_tokens"
    }
}

// MARK: - Client Messages (Send to Server)

/// Setup message sent at connection start
public struct SetupMessage: Codable, Sendable {
    public let setup: SetupConfig

    public init(setup: SetupConfig) {
        self.setup = setup
    }
}

public struct SetupConfig: Codable, Sendable {
    public let model: String
    public let generationConfig: ClientGenerationConfig?
    public let systemInstruction: SystemInstruction?
    public let tools: [Tool]?

    public init(
        model: String,
        generationConfig: ClientGenerationConfig? = nil,
        systemInstruction: SystemInstruction? = nil,
        tools: [Tool]? = nil
    ) {
        self.model = model
        self.generationConfig = generationConfig
        self.systemInstruction = systemInstruction
        self.tools = tools
    }

    enum CodingKeys: String, CodingKey {
        case model
        case generationConfig = "generation_config"
        case systemInstruction = "system_instruction"
        case tools
    }
}

public struct ClientGenerationConfig: Codable, Sendable {
    public let responseModalities: [String]
    public let speechConfig: SpeechConfig?

    public init(responseModalities: [String], speechConfig: SpeechConfig? = nil) {
        self.responseModalities = responseModalities
        self.speechConfig = speechConfig
    }

    enum CodingKeys: String, CodingKey {
        case responseModalities = "response_modalities"
        case speechConfig = "speech_config"
    }
}

public struct SystemInstruction: Codable, Sendable {
    public let parts: [ContentPart]

    public init(text: String) {
        self.parts = [ContentPart(text: text)]
    }
}

public struct Tool: Codable, Sendable {
    public let googleSearch: GoogleSearch?
    public let functionDeclarations: [FunctionDeclaration]?

    public init(googleSearch: GoogleSearch? = nil, functionDeclarations: [FunctionDeclaration]? = nil) {
        self.googleSearch = googleSearch
        self.functionDeclarations = functionDeclarations
    }

    enum CodingKeys: String, CodingKey {
        case googleSearch = "google_search"
        case functionDeclarations = "function_declarations"
    }
}

public struct GoogleSearch: Codable, Sendable {
    public init() {}
}

public struct FunctionDeclaration: Codable, Sendable {
    public let name: String
    public let description: String
    public let parameters: [String: Any]?

    public init(name: String, description: String, parameters: [String: Any]? = nil) {
        self.name = name
        self.description = description
        self.parameters = nil // Simplified for now
    }

    enum CodingKeys: String, CodingKey {
        case name, description
    }
}

/// Real-time audio input message
public struct RealtimeInputMessage: Codable, Sendable {
    public let realtimeInput: RealtimeInput

    public init(realtimeInput: RealtimeInput) {
        self.realtimeInput = realtimeInput
    }

    enum CodingKeys: String, CodingKey {
        case realtimeInput = "realtime_input"
    }
}

public struct RealtimeInput: Codable, Sendable {
    public let mediaChunks: [MediaChunk]

    public init(mediaChunks: [MediaChunk]) {
        self.mediaChunks = mediaChunks
    }

    enum CodingKeys: String, CodingKey {
        case mediaChunks = "media_chunks"
    }
}

public struct MediaChunk: Codable, Sendable {
    public let mimeType: String
    public let data: String // Base64 encoded

    public init(mimeType: String = "audio/pcm;rate=16000", data: String) {
        self.mimeType = mimeType
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

/// Client content message (text or end of turn)
public struct ClientContentMessage: Codable, Sendable {
    public let clientContent: ClientContent

    public init(clientContent: ClientContent) {
        self.clientContent = clientContent
    }

    enum CodingKeys: String, CodingKey {
        case clientContent = "client_content"
    }
}

public struct ClientContent: Codable, Sendable {
    public let turns: [Turn]?
    public let turnComplete: Bool

    public init(turns: [Turn]? = nil, turnComplete: Bool = false) {
        self.turns = turns
        self.turnComplete = turnComplete
    }

    enum CodingKeys: String, CodingKey {
        case turns
        case turnComplete = "turn_complete"
    }
}

public struct Turn: Codable, Sendable {
    public let role: String
    public let parts: [ContentPart]

    public init(role: String = "user", parts: [ContentPart]) {
        self.role = role
        self.parts = parts
    }
}

public struct ContentPart: Codable, Sendable {
    public let text: String?
    public let inlineData: InlineData?

    public init(text: String? = nil, inlineData: InlineData? = nil) {
        self.text = text
        self.inlineData = inlineData
    }

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

public struct InlineData: Codable, Sendable {
    public let mimeType: String
    public let data: String // Base64 encoded

    public init(mimeType: String, data: String) {
        self.mimeType = mimeType
        self.data = data
    }

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

// MARK: - Server Messages (Receive from Server)

/// Union type for all possible server messages
public enum ServerMessage: Sendable {
    case setupComplete(SetupCompleteMessage)
    case serverContent(ServerContentMessage)
    case toolCall(ToolCallMessage)
    case toolCallCancellation(ToolCallCancellationMessage)
    case error(ErrorMessage)
    case unknown(Data)
}

public struct SetupCompleteMessage: Codable, Sendable {
    public let setupComplete: SetupComplete
}

public struct SetupComplete: Codable, Sendable {
    // Empty for now, can be extended
}

public struct ServerContentMessage: Codable, Sendable {
    public let serverContent: ServerContent
}

public struct ServerContent: Codable, Sendable {
    public let modelTurn: ModelTurn?
    public let turnComplete: Bool?
    public let interrupted: Bool?

    enum CodingKeys: String, CodingKey {
        case modelTurn = "model_turn"
        case turnComplete = "turn_complete"
        case interrupted
    }
}

public struct ModelTurn: Codable, Sendable {
    public let parts: [ModelPart]
}

public struct ModelPart: Codable, Sendable {
    public let text: String?
    public let inlineData: InlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

public struct ToolCallMessage: Codable, Sendable {
    public let toolCall: ToolCall
}

public struct ToolCall: Codable, Sendable {
    public let functionCalls: [FunctionCall]

    enum CodingKeys: String, CodingKey {
        case functionCalls = "function_calls"
    }
}

public struct FunctionCall: Codable, Sendable {
    public let id: String
    public let name: String
    public let args: [String: String]?
}

public struct ToolCallCancellationMessage: Codable, Sendable {
    public let toolCallCancellation: ToolCallCancellation
}

public struct ToolCallCancellation: Codable, Sendable {
    public let ids: [String]
}

public struct ErrorMessage: Codable, Sendable {
    public let error: GeminiError
}

public struct GeminiError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let status: String?
}

// MARK: - Audio Format Constants

public enum GeminiAudioFormat {
    /// Input audio format: 16-bit PCM, 16kHz, mono
    public static let inputSampleRate: Double = 16000
    public static let inputBitsPerSample: Int = 16
    public static let inputChannels: Int = 1
    public static let inputMimeType = "audio/pcm;rate=16000"

    /// Output audio format: 24kHz
    public static let outputSampleRate: Double = 24000

    /// Recommended chunk size in bytes
    public static let chunkSize: Int = 1024
}

// MARK: - Translation Mode

/// LiveLingo specific: Translation mode configuration
public struct TranslationMode: Sendable {
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public let bidirectional: Bool

    public init(
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        bidirectional: Bool = true
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.bidirectional = bidirectional
    }

    /// System instruction for translation
    public var systemInstruction: String {
        if bidirectional {
            return """
            You are a real-time interpreter. Your task is to translate speech between \(sourceLanguage.localizedName) and \(targetLanguage.localizedName).

            Rules:
            1. Detect the input language automatically
            2. If the input is in \(sourceLanguage.localizedName), translate to \(targetLanguage.localizedName)
            3. If the input is in \(targetLanguage.localizedName), translate to \(sourceLanguage.localizedName)
            4. Preserve the tone, emotion, and intent of the original speech
            5. Respond only with the translation, no explanations
            6. Use natural, conversational language
            """
        } else {
            return """
            You are a real-time interpreter. Translate all speech from \(sourceLanguage.localizedName) to \(targetLanguage.localizedName).

            Rules:
            1. Preserve the tone, emotion, and intent of the original speech
            2. Respond only with the translation, no explanations
            3. Use natural, conversational language
            """
        }
    }
}
