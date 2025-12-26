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

// MARK: - WebSocket Delegate Handler

/// Handles URLSessionWebSocketDelegate callbacks and forwards to actor
private final class WebSocketDelegateHandler: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private var onOpen: (() -> Void)?
    private var onClose: ((URLSessionWebSocketTask.CloseCode, Data?) -> Void)?
    private var onError: ((Error) -> Void)?
    private let lock = NSLock()

    func setCallbacks(
        onOpen: @escaping () -> Void,
        onClose: @escaping (URLSessionWebSocketTask.CloseCode, Data?) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.onOpen = onOpen
        self.onClose = onClose
        self.onError = onError
    }

    func clearCallbacks() {
        lock.lock()
        defer { lock.unlock() }
        self.onOpen = nil
        self.onClose = nil
        self.onError = nil
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("[GeminiLive] WebSocket didOpen with protocol: \(`protocol` ?? "none")")
        lock.lock()
        let callback = onOpen
        lock.unlock()
        callback?()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        print("[GeminiLive] WebSocket didClose with code: \(closeCode.rawValue)")
        lock.lock()
        let callback = onClose
        lock.unlock()
        callback?(closeCode, reason)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            print("[GeminiLive] WebSocket task completed with error: \(error.localizedDescription)")
            lock.lock()
            let callback = onError
            lock.unlock()
            callback?(error)
        }
    }
}

// MARK: - Gemini Live Service

/// Main service for Gemini Live API real-time translation
public actor GeminiLiveService: GeminiLiveServiceProtocol {
    // MARK: - Properties

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var delegateHandler: WebSocketDelegateHandler?
    private var config: GeminiLiveConfig?
    private var translationMode: TranslationMode?

    private var _isConnected: Bool = false
    private var _isSessionActive: Bool = false
    private var _state: GeminiLiveState = .disconnected

    // Connection management
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var setupContinuation: CheckedContinuation<Void, Error>?
    private var setupTimeoutTask: Task<Void, Never>?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 3
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

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

    // MARK: - Initialization

    public init() {}

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

        // Create delegate handler
        let handler = WebSocketDelegateHandler()
        self.delegateHandler = handler

        // Create URL session with delegate
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 300
        sessionConfig.waitsForConnectivity = true

        // Create session with delegate on main queue for reliability
        urlSession = URLSession(
            configuration: sessionConfig,
            delegate: handler,
            delegateQueue: OperationQueue.main
        )

        // Create WebSocket task
        var request = URLRequest(url: config.webSocketURL)
        request.timeoutInterval = 30

        webSocket = urlSession?.webSocketTask(with: request)

        // Wait for WebSocket connection to open
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectionContinuation = continuation

            // Set up delegate callbacks
            handler.setCallbacks(
                onOpen: { [weak self] in
                    Task { [weak self] in
                        await self?.handleConnectionOpened()
                    }
                },
                onClose: { [weak self] closeCode, reason in
                    Task { [weak self] in
                        await self?.handleConnectionClosed(closeCode: closeCode, reason: reason)
                    }
                },
                onError: { [weak self] error in
                    Task { [weak self] in
                        await self?.handleConnectionError(error)
                    }
                }
            )

            // Start the connection
            self.webSocket?.resume()
            print("[GeminiLive] WebSocket task resumed, waiting for connection...")

            // Set a timeout for connection
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                await self.handleConnectionTimeout()
            }
        }

        // Connection is now open, send setup message
        try await sendSetupMessage()

        // Wait for setupComplete response using event-driven approach (not polling)
        // This eliminates the 100ms polling delay
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setupContinuation = continuation

            // Set timeout task
            self.setupTimeoutTask = Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                if let cont = self.setupContinuation {
                    self.setupContinuation = nil
                    cont.resume(throwing: LiveLingoError.geminiSessionFailed(reason: "Setup timeout - no response from server"))
                }
            }
        }

        // Start heartbeat after session is active
        startHeartbeat()

        print("[GeminiLive] Session setup complete, ready for audio")
    }

    private func handleConnectionOpened() {
        guard let continuation = connectionContinuation else { return }
        connectionContinuation = nil

        print("[GeminiLive] WebSocket connection opened successfully")
        _isConnected = true
        Task {
            await updateState(.connected)
        }

        // Start receiving messages
        receiveTask = Task {
            await self.receiveMessages()
        }

        continuation.resume()
    }

    private func handleConnectionClosed(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        print("[GeminiLive] Connection closed: code=\(closeCode.rawValue), reason=\(reasonString)")

        if let continuation = connectionContinuation {
            connectionContinuation = nil
            continuation.resume(throwing: LiveLingoError.geminiSessionFailed(reason: "Connection closed: \(closeCode.rawValue)"))
        }

        _isConnected = false
        _isSessionActive = false
    }

    private func handleConnectionError(_ error: Error) {
        print("[GeminiLive] Connection error: \(error.localizedDescription)")

        if let continuation = connectionContinuation {
            connectionContinuation = nil
            continuation.resume(throwing: error)
        } else {
            // Error during active session
            Task {
                await handleError(error)
            }
        }
    }

    private func handleConnectionTimeout() {
        guard let continuation = connectionContinuation else { return }
        connectionContinuation = nil
        continuation.resume(throwing: LiveLingoError.geminiSessionFailed(reason: "Connection timeout"))
    }

    /// Start heartbeat to keep connection alive
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled && _isConnected {
                try? await Task.sleep(nanoseconds: 25_000_000_000) // 25 seconds
                guard _isConnected, let webSocket = webSocket else { break }

                do {
                    try await webSocket.sendPing { error in
                        if let error = error {
                            print("[GeminiLive] Heartbeat ping failed: \(error)")
                        } else {
                            print("[GeminiLive] Heartbeat ping successful")
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

        // Cancel tasks
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        setupTimeoutTask?.cancel()
        setupTimeoutTask = nil

        // Clear delegate callbacks
        delegateHandler?.clearCallbacks()
        delegateHandler = nil

        // Cancel connection continuation if pending
        if let continuation = connectionContinuation {
            connectionContinuation = nil
            continuation.resume(throwing: LiveLingoError.geminiNotConnected)
        }

        // Cancel setup continuation if pending
        if let continuation = setupContinuation {
            setupContinuation = nil
            continuation.resume(throwing: LiveLingoError.geminiNotConnected)
        }

        // Close WebSocket
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil

        // Invalidate session
        urlSession?.invalidateAndCancel()
        urlSession = nil

        _isConnected = false
        _isSessionActive = false
        config = nil
        translationMode = nil
        audioBuffer = Data()
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

        // NOTE: Use "audio" field, NOT deprecated "mediaChunks"
        let message = RealtimeInputMessage(
            realtimeInput: RealtimeInput(
                audio: AudioBlob(
                    mimeType: GeminiAudioFormat.inputMimeType,
                    data: base64Audio
                )
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

        // NOTE: gemini-2.5-flash-native-audio model only supports AUDIO modality
        // TEXT and speechConfig cause "invalid argument" errors
        let generationConfig = ClientGenerationConfig(
            responseModalities: ["AUDIO"],  // AUDIO only - TEXT not supported
            speechConfig: nil  // Use default voice - custom speechConfig causes errors
        )

        let setup = SetupConfig(
            model: config.model.rawValue,
            generationConfig: generationConfig,
            systemInstruction: SystemInstruction(text: translationMode.systemInstruction),  // Content object with parts
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

        guard _isConnected else {
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
            while _isConnected && !Task.isCancelled {
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
            if _isConnected && !Task.isCancelled {
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

        // Cancel timeout task and resume continuation (event-driven completion)
        setupTimeoutTask?.cancel()
        setupTimeoutTask = nil

        if let continuation = setupContinuation {
            setupContinuation = nil
            continuation.resume()
        }

        await updateState(.ready)
    }

    private func handleServerContent(_ message: ServerContentMessage) async {
        let content = message.serverContent

        // Check if interrupted
        if content.interrupted == true {
            print("[GeminiLive] Turn interrupted - resuming listening mode")
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

        // Check if turn is complete - IMPORTANT: Go back to listening for continuous conversation
        if content.turnComplete == true {
            print("[GeminiLive] Turn complete - returning to listening mode for continuous conversation")
            // NOTE: Use .listening instead of .ready to indicate we're actively waiting for input
            // This ensures the UI shows we're ready for more input
            await updateState(.listening)
        }
    }

    private func handleTextOutput(_ text: String) async {
        guard let translationMode = translationMode else { return }

        // The text from Gemini is the translation
        _onTranslation?(text, translationMode.targetLanguage)
    }

    private func handleAudioOutput(_ data: Data) async {
        print("[GeminiLive] Received audio output: \(data.count) bytes")
        await updateState(.speaking)
        _onAudioOutput?(data)
    }

    private func handleToolCall(_ message: ToolCallMessage) async {
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
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
            return true
        }

        return false
    }

    private func attemptReconnection() async {
        guard let config = config, let translationMode = translationMode else { return }

        reconnectAttempts += 1
        print("[GeminiLive] Attempting reconnection (\(reconnectAttempts)/\(maxReconnectAttempts))...")

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
