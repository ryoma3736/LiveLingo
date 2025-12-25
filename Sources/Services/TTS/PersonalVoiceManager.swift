import Foundation
import AVFoundation

// MARK: - Personal Voice Authorization Status

/// Status of Personal Voice authorization
public enum PersonalVoiceAuthorizationStatus: String, Sendable {
    case notDetermined
    case denied
    case authorized
    case unsupported
    case notAvailable

    @available(iOS 17.0, *)
    public init(from status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .unsupported:
            self = .unsupported
        @unknown default:
            self = .unsupported
        }
    }

    public var description: String {
        switch self {
        case .notDetermined:
            return "Permission not yet requested"
        case .denied:
            return "Permission denied by user"
        case .authorized:
            return "Personal Voice authorized"
        case .unsupported:
            return "Personal Voice not supported on this device"
        case .notAvailable:
            return "Personal Voice not available"
        }
    }

    public var isAuthorized: Bool {
        self == .authorized
    }

    public var canRequest: Bool {
        self == .notDetermined
    }
}

// MARK: - Personal Voice Info

/// Information about a Personal Voice
public struct PersonalVoiceInfo: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let language: SupportedLanguage?
    public let isDefault: Bool

    public init(
        id: String,
        name: String,
        language: SupportedLanguage?,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.isDefault = isDefault
    }

    @available(iOS 17.0, *)
    public init?(from voice: AVSpeechSynthesisVoice) {
        guard voice.voiceTraits.contains(.isPersonalVoice) else {
            return nil
        }

        self.id = voice.identifier
        self.name = voice.name
        self.language = SupportedLanguage(rawValue: voice.language)
        self.isDefault = false
    }
}

// MARK: - Personal Voice Manager

/// Manages iOS 17+ Personal Voice functionality
public actor PersonalVoiceManager {
    // MARK: - Properties

    private let synthesizer: AVSpeechSynthesizer
    private var cachedPersonalVoices: [PersonalVoiceInfo] = []
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 60 // 1 minute cache

    // MARK: - Initialization

    public init() {
        self.synthesizer = AVSpeechSynthesizer()
    }

    // MARK: - Availability

    /// Check if Personal Voice is supported on this device
    public nonisolated func isPersonalVoiceSupported() -> Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }

    /// Check if Personal Voice feature is available
    public func isPersonalVoiceAvailable() async -> Bool {
        guard isPersonalVoiceSupported() else { return false }

        if #available(iOS 17.0, *) {
            let status = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
            return status == .authorized && !getPersonalVoices().isEmpty
        }
        return false
    }

    // MARK: - Authorization

    /// Get current authorization status
    public nonisolated func getAuthorizationStatus() -> PersonalVoiceAuthorizationStatus {
        if #available(iOS 17.0, *) {
            return PersonalVoiceAuthorizationStatus(from: AVSpeechSynthesizer.personalVoiceAuthorizationStatus)
        }
        return .unsupported
    }

    /// Request Personal Voice authorization
    public func requestPersonalVoiceAuthorization() async -> PersonalVoiceAuthorizationStatus {
        guard isPersonalVoiceSupported() else {
            return .unsupported
        }

        if #available(iOS 17.0, *) {
            let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
            return PersonalVoiceAuthorizationStatus(from: status)
        }

        return .unsupported
    }

    // MARK: - Voice Management

    /// Get all available Personal Voices
    @available(iOS 17.0, *)
    public func getPersonalVoices() -> [PersonalVoiceInfo] {
        // Check cache
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheDuration,
           !cachedPersonalVoices.isEmpty {
            return cachedPersonalVoices
        }

        // Fetch personal voices
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let personalVoices = allVoices.compactMap { PersonalVoiceInfo(from: $0) }

        // Update cache
        cachedPersonalVoices = personalVoices
        lastFetchTime = Date()

        return personalVoices
    }

    /// Get Personal Voices for a specific language
    @available(iOS 17.0, *)
    public func getPersonalVoices(for language: SupportedLanguage) -> [PersonalVoiceInfo] {
        getPersonalVoices().filter { $0.language == language }
    }

    /// Check if user has created any Personal Voices
    @available(iOS 17.0, *)
    public func hasPersonalVoices() -> Bool {
        !getPersonalVoices().isEmpty
    }

    /// Clear cached voices
    public func clearCache() {
        cachedPersonalVoices.removeAll()
        lastFetchTime = nil
    }

    // MARK: - Speech Synthesis

    /// Speak text using Personal Voice
    @available(iOS 17.0, *)
    public func speakWithPersonalVoice(
        text: String,
        voiceID: String? = nil
    ) async throws {
        // Check authorization
        let status = getAuthorizationStatus()
        guard status.isAuthorized else {
            throw PersonalVoiceError.notAuthorized(status: status)
        }

        // Get personal voice
        let personalVoices = getPersonalVoices()
        guard !personalVoices.isEmpty else {
            throw PersonalVoiceError.noPersonalVoicesAvailable
        }

        // Find specific voice or use first available
        let selectedVoice: PersonalVoiceInfo
        if let voiceID = voiceID {
            guard let voice = personalVoices.first(where: { $0.id == voiceID }) else {
                throw PersonalVoiceError.voiceNotFound(id: voiceID)
            }
            selectedVoice = voice
        } else {
            selectedVoice = personalVoices[0]
        }

        // Create and speak utterance
        try await speak(text: text, voiceID: selectedVoice.id)
    }

    private func speak(text: String, voiceID: String) async throws {
        guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
            throw PersonalVoiceError.voiceNotFound(id: voiceID)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PersonalVoiceDelegate(
                onFinish: {
                    continuation.resume()
                },
                onError: { error in
                    continuation.resume(throwing: error)
                }
            )

            // Keep delegate alive
            objc_setAssociatedObject(
                synthesizer,
                "personalVoiceDelegate",
                delegate,
                .OBJC_ASSOCIATION_RETAIN
            )

            synthesizer.delegate = delegate
            synthesizer.speak(utterance)
        }
    }

    /// Stop current speech
    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Check if currently speaking
    public func isSpeaking() -> Bool {
        synthesizer.isSpeaking
    }

    // MARK: - Settings Integration

    /// Get URL to open Personal Voice settings
    public nonisolated func getSettingsURL() -> URL? {
        if #available(iOS 17.0, *) {
            // Direct URL to Accessibility > Personal Voice settings
            return URL(string: "App-Prefs:root=ACCESSIBILITY&path=PERSONAL_VOICE")
        }
        return nil
    }

    /// Convert to VoiceOption for integration with TTS service
    public func toVoiceOption(_ personalVoice: PersonalVoiceInfo) -> VoiceOption {
        VoiceOption(
            id: personalVoice.id,
            name: "Personal: \(personalVoice.name)",
            language: personalVoice.language ?? .englishUS,
            provider: .personal,
            isDefault: false
        )
    }
}

// MARK: - Personal Voice Error

/// Errors specific to Personal Voice functionality
public enum PersonalVoiceError: LocalizedError, Sendable {
    case notSupported
    case notAuthorized(status: PersonalVoiceAuthorizationStatus)
    case noPersonalVoicesAvailable
    case voiceNotFound(id: String)
    case synthesisFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Personal Voice requires iOS 17 or later"
        case .notAuthorized(let status):
            return "Personal Voice not authorized: \(status.description)"
        case .noPersonalVoicesAvailable:
            return "No Personal Voices have been created. Create one in Settings > Accessibility > Personal Voice"
        case .voiceNotFound(let id):
            return "Personal Voice not found: \(id)"
        case .synthesisFailed(let reason):
            return "Personal Voice synthesis failed: \(reason)"
        }
    }
}

// MARK: - Personal Voice Delegate

private final class PersonalVoiceDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let onFinish: () -> Void
    private let onError: (Error) -> Void

    init(onFinish: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onFinish = onFinish
        self.onError = onError
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish()
    }
}

// MARK: - Personal Voice + AppleTTSService Integration

extension AppleTTSService {
    /// Check if Personal Voice is available
    public func isPersonalVoiceAvailable() async -> Bool {
        let manager = PersonalVoiceManager()
        return await manager.isPersonalVoiceAvailable()
    }

    /// Get available Personal Voices
    @available(iOS 17.0, *)
    public func getPersonalVoices() async -> [VoiceOption] {
        let manager = PersonalVoiceManager()
        let voices = await manager.getPersonalVoices()
        var result: [VoiceOption] = []
        for voice in voices {
            result.append(await manager.toVoiceOption(voice))
        }
        return result
    }

    /// Speak using Personal Voice with fallback
    @available(iOS 17.0, *)
    public func speakWithPersonalVoiceOrFallback(
        text: String,
        personalVoiceID: String? = nil,
        fallbackVoice: VoiceOption
    ) async throws {
        let manager = PersonalVoiceManager()

        // Try Personal Voice first
        if await manager.isPersonalVoiceAvailable() {
            do {
                try await manager.speakWithPersonalVoice(text: text, voiceID: personalVoiceID)
                return
            } catch {
                // Fall through to fallback
                print("Personal Voice failed, using fallback: \(error.localizedDescription)")
            }
        }

        // Use fallback voice
        try await speak(text, voice: fallbackVoice)
    }
}
