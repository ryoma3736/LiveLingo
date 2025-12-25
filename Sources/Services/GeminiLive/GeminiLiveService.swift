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

    func setOnTranscript(_ handler: (@Sendable (String, SupportedLanguage) -> Void)?) async
    func setOnTranslation(_ handler: (@Sendable (String, SupportedLanguage) -> Void)?) async
    func setOnAudioOutput(_ handler: (@Sendable (Data) -> Void)?) async
    func setOnError(_ handler: (@Sendable (Error) -> Void)?) async
    func setOnStateChange(_ handler: (@Sendable (GeminiLiveState) -> Void)?) async
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

    // Connection management
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 3
    private var heartbeatTask: Task<Void, Never>?

    public var isConnected: Bool { _isConnected }
    public var isSessionActive: Bool { _isSessionActive }
    public var state: GeminiLiveState { _state }

    // MARK: - Callbacks

    private var _onTranscript: (@Sendable (String, SupportedLanguage) -> Void)?
    private var _onTranslation: (@Sendable (String, SupportedLanguage) -> Void)?
    private var _onAudioOutput: (@Sendable (Data) -> Void)?
    private var _onError: (@Sendable (Error) -> Void)?
    private var _onStateChange: (@Sendable (GeminiLiveState) -> Void)?

    public func setOnTranscript(_ handler: (@Sendable (String, SupportedLanguage) -> Void)?) {
        _onTranscript = handler
    }

    public func setOnTranslation(_ handler: (@Sendable (String, SupportedLanguage) -> Void)?) {
        _onTranslation = handler
    }

    public func setOnAudioOutput(_ handler: (@Sendable (Data) -> Void)?) {
        _onAudioOutput = handler
    }

    public func setOnError(_ handler: (@Sendable (Error) -> Void)?) {
        _onError = handler
    }

    public func setOnStateChange(_ handler: (@Sendable (GeminiLiveState) -> Void)?) {
        _onStateChange = handler
    }

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
        self.reconnectAttempts = 0

        await updateState(.connecting)

        print("[GeminiLive] Connecting to WebSocket...")
        print("[GeminiLive] URL: \(config.webSocketURL)")
        print("[GeminiLive] Model: \(config.model.rawValue)")

        // Create URL session with proper configuration
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 300 // 5 minutes
        sessionConfig.timeoutIntervalForResource = 3600 // 1 hour
        sessionConfig.waitsForConnectivity = true

        urlSession = URLSession(configuration: sessionConfig)

        // Create WebSocket task with proper headers
        var request = URLRequest(url: config.webSocketURL)
        request.timeoutInterval = 30
        request.setValue("permessage-deflate; client_max_window_bits", forHTTPHeaderField: "Sec-WebSocket-Extensions")

        webSocket = urlSession?.webSocketTask(with: request)

        // Wait for connection to establish
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation

            // Resume the WebSocket task
            self.webSocket?.resume()

            // Set a timeout for connection establishment
            Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
                if !self._isConnected {
                    self.connectionContinuation?.resume(throwing: LiveLingoError.geminiSessionFailed(reason: "Connection timeout"))
                    self.connectionContinuation = nil
                }
            }

            // Mark as connected once resumed (WebSocket establishes on resume)
            Task {
                // Small delay to ensure connection is established
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if self.webSocket != nil {
                    self._isConnected = true
                    await self.updateState(.connected)
                    print("[GeminiLive] WebSocket connected successfully")

                    // Start receiving messages
                    Task {
                        await self.receiveMessages()
                    }

                    // Start heartbeat
                    self.startHeartbeat()

                    // Send setup message
                    do {
                        try await self.sendSetupMessage()
                        self.connectionContinuation?.resume()
                        self.connectionContinuation = nil
                    } catch {
                        self.connectionContinuation?.resume(throwing: error)
                        self.connectionContinuation = nil
                    }
                }
            }
        }
    }

    /// Start heartbeat to keep connection alive
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled && _isConnected {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard _isConnected, let webSocket = webSocket else { break }

                do {
                    try await webSocket.sendPing { error in
                        if let error = error {
                            print("[GeminiLive] Heartbeat ping failed: \(error)")
                        }
                    }
                } catch {
                    print("[GeminiLive] Heartbeat error: \(error)")
                }
            }
        }
    }

    public func disconnect() async {
        print("[GeminiLive] Disconnecting...")

        heartbeatTask?.cancel()
        heartbeatTask = nil

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil

        _isConnected = false
        _isSessionActive = false
        config = nil
        translationMode = nil
        audioBuffer = Data()
        connectionContinuation = nil
        reconnectAttempts = 0

        await updateState(.disconnected)
        print("[GeminiLive] Disconnected")
    }

    // MARK: - Send Messages

    public func sendAudio(_ data: Data) async throws {
        guard _isSessionActive else {
            throw LiveLingoError.geminiNotConnected
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
            throw LiveLingoError.geminiNotConnected
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
            throw LiveLingoError.geminiNotConnected
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
            throw LiveLingoError.geminiSessionFailed(reason: "Configuration missing")
        }

        await updateState(.setupPending)
        print("[GeminiLive] Sending setup message...")

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

        #if DEBUG
        if let jsonData = try? JSONEncoder().encode(message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[GeminiLive] Setup message: \(jsonString.prefix(500))...")
        }
        #endif

        try await sendMessage(message)
        print("[GeminiLive] Setup message sent successfully")
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
        print("[GeminiLive] Setup complete - session is now active")
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
        _onTranslation?(text, translationMode.targetLanguage)
    }

    private func handleAudioOutput(_ data: Data) async {
        await updateState(.speaking)
        _onAudioOutput?(data)
    }

    private func handleToolCall(_ message: ToolCallMessage) async {
        // Handle function calls if needed
        #if DEBUG
        print("[GeminiLive] Tool call received: \(message.toolCall.functionCalls)")
        #endif
    }

    private func handleErrorMessage(_ message: ErrorMessage) async {
        let error = LiveLingoError.networkRequestFailed(
            statusCode: message.error.code,
            message: message.error.message
        )
        await handleError(error)
    }

    private func handleError(_ error: Error) async {
        print("[GeminiLive] Error occurred: \(error.localizedDescription)")
        await updateState(.error(error.localizedDescription))
        _onError?(error)

        // Attempt reconnection for recoverable errors
        if shouldAttemptReconnection(for: error) && reconnectAttempts < maxReconnectAttempts {
            await attemptReconnection()
        }
    }

    private func shouldAttemptReconnection(for error: Error) -> Bool {
        // Implement reconnection logic based on error type
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        // Check for WebSocket-specific errors
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain {
            // ENOTCONN (57) - Socket is not connected
            if nsError.code == 57 {
                return true
            }
        }

        return false
    }

    private func attemptReconnection() async {
        guard let config = config, let translationMode = translationMode else { return }

        reconnectAttempts += 1
        print("[GeminiLive] Attempting reconnection (\(reconnectAttempts)/\(maxReconnectAttempts))...")

        // Exponential backoff: 2s, 4s, 8s
        let backoffSeconds = UInt64(pow(2.0, Double(reconnectAttempts)))
        try? await Task.sleep(nanoseconds: backoffSeconds * 1_000_000_000)

        do {
            await disconnect()
            try await connect(config: config, translationMode: translationMode)
            print("[GeminiLive] Reconnection successful")
            reconnectAttempts = 0
        } catch {
            print("[GeminiLive] Reconnection failed: \(error)")
            if reconnectAttempts >= maxReconnectAttempts {
                print("[GeminiLive] Max reconnection attempts reached")
                await handleError(error)
            }
        }
    }

    private func updateState(_ newState: GeminiLiveState) async {
        _state = newState
        _onStateChange?(newState)
    }
}

