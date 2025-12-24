import Foundation
import AVFoundation

// MARK: - Gemini Live Service Protocol

/// Protocol for Gemini Live API service
public protocol GeminiLiveServiceProtocol: Sendable {
    var isConnected: Bool { get async }
    var isSessionActive: Bool { get async }

    func connect(config: GeminiLiveConfig, translationMode: TranslationMode) async throws
    func disconnect() async
    func sendAudio(_ data: Data) async throws
    func sendText(_ text: String) async throws
    func endTurn() async throws

    var onTranscript: (@Sendable (String, SupportedLanguage) -> Void)? { get set }
    var onTranslation: (@Sendable (String, SupportedLanguage) -> Void)? { get set }
    var onAudioOutput: (@Sendable (Data) -> Void)? { get set }
    var onError: (@Sendable (Error) -> Void)? { get set }
    var onStateChange: (@Sendable (GeminiLiveState) -> Void)? { get set }
}

// MARK: - Connection State

public enum GeminiLiveState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case setupPending
    case ready
    case listening
    case processing
    case speaking
    case error(String)
}

// MARK: - Gemini Live Service

/// Main service for Gemini Live API real-time translation
public actor GeminiLiveService: NSObject, GeminiLiveServiceProtocol {
    // MARK: - Properties

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var config: GeminiLiveConfig?
    private var translationMode: TranslationMode?

    private var _isConnected: Bool = false
    private var _isSessionActive: Bool = false
    private var _state: GeminiLiveState = .disconnected

    public var isConnected: Bool { _isConnected }
    public var isSessionActive: Bool { _isSessionActive }
    public var state: GeminiLiveState { _state }

    // MARK: - Callbacks

    public var onTranscript: (@Sendable (String, SupportedLanguage) -> Void)?
    public var onTranslation: (@Sendable (String, SupportedLanguage) -> Void)?
    public var onAudioOutput: (@Sendable (Data) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?
    public var onStateChange: (@Sendable (GeminiLiveState) -> Void)?

    // MARK: - Audio Processing

    private var audioBuffer = Data()
    private let audioQueue = DispatchQueue(label: "com.livelingo.gemini.audio")

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - Connection Management

    public func connect(config: GeminiLiveConfig, translationMode: TranslationMode) async throws {
        guard !_isConnected else {
            throw LiveLingoError.geminiAlreadyConnected
        }

        self.config = config
        self.translationMode = translationMode

        await updateState(.connecting)

        // Create URL session
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 300 // 5 minutes
        sessionConfig.timeoutIntervalForResource = 3600 // 1 hour

        urlSession = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

        // Create WebSocket task
        var request = URLRequest(url: config.webSocketURL)
        request.timeoutInterval = 300

        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()

        _isConnected = true
        await updateState(.connected)

        // Start receiving messages
        Task {
            await receiveMessages()
        }

        // Send setup message
        try await sendSetupMessage()
    }

    public func disconnect() async {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        _isConnected = false
        _isSessionActive = false
        config = nil
        translationMode = nil
        audioBuffer = Data()

        await updateState(.disconnected)
    }

    // MARK: - Send Messages

    public func sendAudio(_ data: Data) async throws {
        guard _isSessionActive else {
            throw LiveLingoError.geminiSessionNotActive
        }

        // Convert to base64
        let base64Audio = data.base64EncodedString()

        let message = RealtimeInputMessage(
            realtimeInput: RealtimeInput(
                mediaChunks: [
                    MediaChunk(
                        mimeType: GeminiAudioFormat.inputMimeType,
                        data: base64Audio
                    )
                ]
            )
        )

        try await sendMessage(message)

        if _state != .listening {
            await updateState(.listening)
        }
    }

    public func sendText(_ text: String) async throws {
        guard _isSessionActive else {
            throw LiveLingoError.geminiSessionNotActive
        }

        let message = ClientContentMessage(
            clientContent: ClientContent(
                turns: [
                    Turn(role: "user", parts: [ContentPart(text: text)])
                ],
                turnComplete: true
            )
        )

        try await sendMessage(message)
        await updateState(.processing)
    }

    public func endTurn() async throws {
        guard _isSessionActive else {
            throw LiveLingoError.geminiSessionNotActive
        }

        let message = ClientContentMessage(
            clientContent: ClientContent(turnComplete: true)
        )

        try await sendMessage(message)
        await updateState(.processing)
    }

    // MARK: - Private Methods

    private func sendSetupMessage() async throws {
        guard let config = config, let translationMode = translationMode else {
            throw LiveLingoError.geminiConfigurationMissing
        }

        await updateState(.setupPending)

        let voiceConfig = VoiceConfig(
            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: "Aoede") // Natural voice
        )

        let generationConfig = ClientGenerationConfig(
            responseModalities: config.responseModalities.map { $0.rawValue },
            speechConfig: SpeechConfig(voiceConfig: voiceConfig)
        )

        let setup = SetupConfig(
            model: config.model.rawValue,
            generationConfig: generationConfig,
            systemInstruction: SystemInstruction(text: translationMode.systemInstruction),
            tools: nil
        )

        let message = SetupMessage(setup: setup)
        try await sendMessage(message)
    }

    private func sendMessage<T: Encodable>(_ message: T) async throws {
        guard let webSocket = webSocket else {
            throw LiveLingoError.geminiNotConnected
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        let wsMessage = URLSessionWebSocketTask.Message.data(data)
        try await webSocket.send(wsMessage)
    }

    private func receiveMessages() async {
        guard let webSocket = webSocket else { return }

        do {
            while _isConnected {
                let message = try await webSocket.receive()

                switch message {
                case .data(let data):
                    await handleMessage(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        await handleMessage(data)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            if _isConnected {
                await handleError(error)
            }
        }
    }

    private func handleMessage(_ data: Data) async {
        let decoder = JSONDecoder()

        // Try to parse different message types
        if let setupComplete = try? decoder.decode(SetupCompleteMessage.self, from: data) {
            await handleSetupComplete(setupComplete)
        } else if let serverContent = try? decoder.decode(ServerContentMessage.self, from: data) {
            await handleServerContent(serverContent)
        } else if let toolCall = try? decoder.decode(ToolCallMessage.self, from: data) {
            await handleToolCall(toolCall)
        } else if let errorMessage = try? decoder.decode(ErrorMessage.self, from: data) {
            await handleErrorMessage(errorMessage)
        } else {
            // Unknown message type
            #if DEBUG
            if let json = String(data: data, encoding: .utf8) {
                print("[GeminiLive] Unknown message: \(json.prefix(200))")
            }
            #endif
        }
    }

    private func handleSetupComplete(_ message: SetupCompleteMessage) async {
        _isSessionActive = true
        await updateState(.ready)
    }

    private func handleServerContent(_ message: ServerContentMessage) async {
        let content = message.serverContent

        // Check if interrupted
        if content.interrupted == true {
            await updateState(.listening)
            return
        }

        // Process model turn
        if let modelTurn = content.modelTurn {
            for part in modelTurn.parts {
                // Handle text output (transcript/translation)
                if let text = part.text, !text.isEmpty {
                    await handleTextOutput(text)
                }

                // Handle audio output
                if let inlineData = part.inlineData,
                   inlineData.mimeType.contains("audio"),
                   let audioData = Data(base64Encoded: inlineData.data) {
                    await handleAudioOutput(audioData)
                }
            }
        }

        // Check if turn is complete
        if content.turnComplete == true {
            await updateState(.ready)
        }
    }

    private func handleTextOutput(_ text: String) async {
        guard let translationMode = translationMode else { return }

        // The text from Gemini is the translation
        // We assume it's translated to the target language
        onTranslation?(text, translationMode.targetLanguage)
    }

    private func handleAudioOutput(_ data: Data) async {
        await updateState(.speaking)
        onAudioOutput?(data)
    }

    private func handleToolCall(_ message: ToolCallMessage) async {
        // Handle function calls if needed
        #if DEBUG
        print("[GeminiLive] Tool call received: \(message.toolCall.functionCalls)")
        #endif
    }

    private func handleErrorMessage(_ message: ErrorMessage) async {
        let error = LiveLingoError.geminiAPIError(
            code: message.error.code,
            message: message.error.message
        )
        await handleError(error)
    }

    private func handleError(_ error: Error) async {
        await updateState(.error(error.localizedDescription))
        onError?(error)

        // Attempt reconnection for recoverable errors
        if shouldAttemptReconnection(for: error) {
            await attemptReconnection()
        }
    }

    private func shouldAttemptReconnection(for error: Error) -> Bool {
        // Implement reconnection logic based on error type
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .notConnectedToInternet, .timedOut:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func attemptReconnection() async {
        guard let config = config, let translationMode = translationMode else { return }

        // Wait before reconnecting
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        do {
            await disconnect()
            try await connect(config: config, translationMode: translationMode)
        } catch {
            await handleError(error)
        }
    }

    private func updateState(_ newState: GeminiLiveState) async {
        _state = newState
        onStateChange?(newState)
    }
}

// MARK: - Error Extensions

extension LiveLingoError {
    static var geminiAlreadyConnected: LiveLingoError {
        .sttAlreadyRecognizing
    }

    static var geminiNotConnected: LiveLingoError {
        .networkUnavailable
    }

    static var geminiSessionNotActive: LiveLingoError {
        .sttNotAvailable(reason: "Gemini session is not active")
    }

    static var geminiConfigurationMissing: LiveLingoError {
        .sttNotAvailable(reason: "Gemini configuration is missing")
    }

    static func geminiAPIError(code: Int, message: String) -> LiveLingoError {
        .networkRequestFailed(statusCode: code, message: message)
    }
}
