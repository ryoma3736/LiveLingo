import Foundation
import Combine

#if os(iOS) || os(watchOS)
import WatchConnectivity
#endif

// MARK: - Watch Message Types

/// Types of messages that can be sent between iOS and watchOS
public enum WatchMessageType: String, Codable, Sendable {
    case startInterpretation
    case stopInterpretation
    case updateLanguage
    case translationResult
    case statusUpdate
    case syncSettings
    case requestStatus
}

// MARK: - Watch Message

/// Message structure for iOS ⇔ watchOS communication
public struct WatchMessage: Codable, Sendable {
    public let id: UUID
    public let type: WatchMessageType
    public let payload: [String: String]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        type: WatchMessageType,
        payload: [String: String] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
    }

    /// Create from dictionary
    public init?(from dictionary: [String: Any]) {
        guard let typeRaw = dictionary["type"] as? String,
              let type = WatchMessageType(rawValue: typeRaw),
              let idString = dictionary["id"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }

        self.id = id
        self.type = type
        self.payload = dictionary["payload"] as? [String: String] ?? [:]
        self.timestamp = (dictionary["timestamp"] as? Date) ?? Date()
    }

    /// Convert to dictionary for sending
    public func toDictionary() -> [String: Any] {
        [
            "id": id.uuidString,
            "type": type.rawValue,
            "payload": payload,
            "timestamp": timestamp
        ]
    }
}

// MARK: - Watch Connection State

/// State of the watch connection
public enum WatchConnectionState: String, Sendable {
    case notSupported
    case notPaired
    case notInstalled
    case notReachable
    case connected
    case unknown
}

// MARK: - Watch Connectivity Manager

#if os(iOS) || os(watchOS)
/// Manages communication between iOS and watchOS apps
public final class WatchConnectivityManager: NSObject, @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = WatchConnectivityManager()

    // MARK: - Properties

    private var session: WCSession?
    private let messageSubject = PassthroughSubject<WatchMessage, Never>()
    private let stateSubject = CurrentValueSubject<WatchConnectionState, Never>(.unknown)
    private var pendingMessages: [WatchMessage] = []

    // MARK: - Public Publishers

    public var messagePublisher: AnyPublisher<WatchMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    public var statePublisher: AnyPublisher<WatchConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var currentState: WatchConnectionState {
        stateSubject.value
    }

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Activation

    /// Activate the Watch Connectivity session
    public func activate() {
        guard WCSession.isSupported() else {
            stateSubject.send(.notSupported)
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Connection Status

    /// Check if watch is reachable
    public var isReachable: Bool {
        session?.isReachable ?? false
    }

    /// Check if watch app is installed
    public var isWatchAppInstalled: Bool {
        #if os(iOS)
        return session?.isWatchAppInstalled ?? false
        #else
        return true
        #endif
    }

    /// Check if paired
    public var isPaired: Bool {
        #if os(iOS)
        return session?.isPaired ?? false
        #else
        return true
        #endif
    }

    // MARK: - Message Sending

    /// Send a message to the paired device
    public func sendMessage(_ message: WatchMessage, completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let session = session, session.activationState == .activated else {
            completion?(.failure(WatchConnectivityError.sessionNotActive))
            return
        }

        guard session.isReachable else {
            // Queue message for later
            pendingMessages.append(message)
            completion?(.failure(WatchConnectivityError.notReachable))
            return
        }

        session.sendMessage(message.toDictionary(), replyHandler: { _ in
            completion?(.success(()))
        }, errorHandler: { error in
            completion?(.failure(error))
        })
    }

    /// Send message with async/await
    public func sendMessage(_ message: WatchMessage) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sendMessage(message) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Transfer user info (guaranteed delivery)
    public func transferUserInfo(_ userInfo: [String: Any]) {
        session?.transferUserInfo(userInfo)
    }

    /// Update application context (latest state only)
    public func updateApplicationContext(_ context: [String: Any]) throws {
        try session?.updateApplicationContext(context)
    }

    // MARK: - Convenience Methods

    /// Send start interpretation command
    public func sendStartInterpretation(
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) async throws {
        let message = WatchMessage(
            type: .startInterpretation,
            payload: [
                "sourceLanguage": sourceLanguage.rawValue,
                "targetLanguage": targetLanguage.rawValue
            ]
        )
        try await sendMessage(message)
    }

    /// Send stop interpretation command
    public func sendStopInterpretation() async throws {
        let message = WatchMessage(type: .stopInterpretation)
        try await sendMessage(message)
    }

    /// Send translation result
    public func sendTranslationResult(
        original: String,
        translated: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) async throws {
        let message = WatchMessage(
            type: .translationResult,
            payload: [
                "original": original,
                "translated": translated,
                "sourceLanguage": sourceLanguage.rawValue,
                "targetLanguage": targetLanguage.rawValue
            ]
        )
        try await sendMessage(message)
    }

    /// Send status update
    public func sendStatusUpdate(isInterpreting: Bool, currentLanguages: String) async throws {
        let message = WatchMessage(
            type: .statusUpdate,
            payload: [
                "isInterpreting": String(isInterpreting),
                "currentLanguages": currentLanguages
            ]
        )
        try await sendMessage(message)
    }

    // MARK: - Private Methods

    private func updateConnectionState() {
        guard let session = session else {
            stateSubject.send(.unknown)
            return
        }

        guard WCSession.isSupported() else {
            stateSubject.send(.notSupported)
            return
        }

        #if os(iOS)
        guard session.isPaired else {
            stateSubject.send(.notPaired)
            return
        }

        guard session.isWatchAppInstalled else {
            stateSubject.send(.notInstalled)
            return
        }
        #endif

        if session.isReachable {
            stateSubject.send(.connected)
        } else {
            stateSubject.send(.notReachable)
        }
    }

    private func sendPendingMessages() {
        guard isReachable else { return }

        let messages = pendingMessages
        pendingMessages.removeAll()

        for message in messages {
            sendMessage(message) { _ in }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Watch Connectivity activation failed: \(error.localizedDescription)")
            stateSubject.send(.unknown)
        } else {
            updateConnectionState()
            sendPendingMessages()
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        updateConnectionState()

        if session.isReachable {
            sendPendingMessages()
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        stateSubject.send(.notReachable)
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate for new watch
        self.session = WCSession.default
        self.session?.delegate = self
        self.session?.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        updateConnectionState()
    }
    #endif

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleReceivedMessage(userInfo)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleReceivedMessage(applicationContext)
    }

    private func handleReceivedMessage(_ dictionary: [String: Any]) {
        if let message = WatchMessage(from: dictionary) {
            DispatchQueue.main.async {
                self.messageSubject.send(message)
            }
        }
    }
}
#endif // os(iOS) || os(watchOS)

// MARK: - Watch Connectivity Error

public enum WatchConnectivityError: LocalizedError, Sendable {
    case sessionNotActive
    case notReachable
    case notSupported
    case notPaired
    case notInstalled
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .sessionNotActive:
            return "Watch Connectivity session is not active"
        case .notReachable:
            return "Apple Watch is not reachable"
        case .notSupported:
            return "Watch Connectivity is not supported on this device"
        case .notPaired:
            return "No Apple Watch is paired"
        case .notInstalled:
            return "LiveLingo is not installed on Apple Watch"
        case .encodingFailed:
            return "Failed to encode message"
        case .decodingFailed:
            return "Failed to decode message"
        }
    }
}

// MARK: - Watch App State

/// Shared state between iOS and watchOS
public struct WatchAppState: Codable, Sendable {
    public var isInterpreting: Bool
    public var sourceLanguage: SupportedLanguage
    public var targetLanguage: SupportedLanguage
    public var volume: Float
    public var lastTranslation: LastTranslation?

    public struct LastTranslation: Codable, Sendable {
        public let original: String
        public let translated: String
        public let timestamp: Date
    }

    public init(
        isInterpreting: Bool = false,
        sourceLanguage: SupportedLanguage = .japanese,
        targetLanguage: SupportedLanguage = .englishUS,
        volume: Float = 1.0,
        lastTranslation: LastTranslation? = nil
    ) {
        self.isInterpreting = isInterpreting
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.volume = volume
        self.lastTranslation = lastTranslation
    }

    /// Convert to dictionary for application context
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "isInterpreting": isInterpreting,
            "sourceLanguage": sourceLanguage.rawValue,
            "targetLanguage": targetLanguage.rawValue,
            "volume": volume
        ]

        if let lastTranslation = lastTranslation {
            dict["lastTranslation"] = [
                "original": lastTranslation.original,
                "translated": lastTranslation.translated,
                "timestamp": lastTranslation.timestamp.timeIntervalSince1970
            ]
        }

        return dict
    }

    /// Create from dictionary
    public init?(from dictionary: [String: Any]) {
        guard let isInterpreting = dictionary["isInterpreting"] as? Bool,
              let sourceRaw = dictionary["sourceLanguage"] as? String,
              let targetRaw = dictionary["targetLanguage"] as? String,
              let sourceLanguage = SupportedLanguage(rawValue: sourceRaw),
              let targetLanguage = SupportedLanguage(rawValue: targetRaw) else {
            return nil
        }

        self.isInterpreting = isInterpreting
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.volume = (dictionary["volume"] as? Float) ?? 1.0

        if let translationDict = dictionary["lastTranslation"] as? [String: Any],
           let original = translationDict["original"] as? String,
           let translated = translationDict["translated"] as? String,
           let timestamp = translationDict["timestamp"] as? TimeInterval {
            self.lastTranslation = LastTranslation(
                original: original,
                translated: translated,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
        } else {
            self.lastTranslation = nil
        }
    }
}
