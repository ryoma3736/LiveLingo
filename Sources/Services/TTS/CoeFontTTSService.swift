import Foundation
import CryptoKit
import AVFoundation

// MARK: - CoeFont Voice

/// CoeFont voice model information
public struct CoeFontVoice: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String?
    public let language: String
    public let gender: String?
    public let style: String?
    public let sampleURL: URL?
    public let isPremium: Bool

    public init(
        id: String,
        name: String,
        description: String? = nil,
        language: String,
        gender: String? = nil,
        style: String? = nil,
        sampleURL: URL? = nil,
        isPremium: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.language = language
        self.gender = gender
        self.style = style
        self.sampleURL = sampleURL
        self.isPremium = isPremium
    }

    /// Convert to VoiceOption for integration
    public func toVoiceOption() -> VoiceOption? {
        guard let supportedLanguage = mapLanguageCode() else { return nil }

        return VoiceOption(
            id: id,
            name: name,
            language: supportedLanguage,
            provider: .coeFont,
            isDefault: false
        )
    }

    private func mapLanguageCode() -> SupportedLanguage? {
        switch language.lowercased() {
        case "ja", "ja-jp", "japanese":
            return .japanese
        case "en", "en-us", "english":
            return .englishUS
        case "zh", "zh-cn", "chinese":
            return .chineseSimplified
        case "ko", "ko-kr", "korean":
            return .korean
        default:
            return nil
        }
    }
}

// MARK: - CoeFont Configuration

/// Configuration for CoeFont API
public struct CoeFontConfig: Sendable {
    public let accessKey: String
    public let clientSecret: String
    public let baseURL: String
    public let maxCharacters: Int
    public let rateLimit: Int // requests per minute
    public let defaultSpeed: Float
    public let defaultPitch: Float

    public init(
        accessKey: String,
        clientSecret: String,
        baseURL: String = "https://api.coefont.cloud",
        maxCharacters: Int = 1000,
        rateLimit: Int = 100,
        defaultSpeed: Float = 1.0,
        defaultPitch: Float = 0
    ) {
        self.accessKey = accessKey
        self.clientSecret = clientSecret
        self.baseURL = baseURL
        self.maxCharacters = maxCharacters
        self.rateLimit = rateLimit
        self.defaultSpeed = defaultSpeed
        self.defaultPitch = defaultPitch
    }
}

// MARK: - CoeFont Synthesis Options

/// Options for CoeFont synthesis
public struct CoeFontSynthesisOptions: Sendable {
    public let speed: Float // 0.5 - 2.0
    public let pitch: Float // -12 to 12 semitones
    public let intonation: Float // 0.0 - 2.0
    public let volume: Float // 0.0 - 2.0
    public let format: AudioFormat

    public init(
        speed: Float = 1.0,
        pitch: Float = 0,
        intonation: Float = 1.0,
        volume: Float = 1.0,
        format: AudioFormat = .wav
    ) {
        self.speed = max(0.5, min(2.0, speed))
        self.pitch = max(-12, min(12, pitch))
        self.intonation = max(0.0, min(2.0, intonation))
        self.volume = max(0.0, min(2.0, volume))
        self.format = format
    }

    public enum AudioFormat: String, Sendable {
        case wav
        case mp3
        case ogg
    }

    public static let `default` = CoeFontSynthesisOptions()
}

// MARK: - CoeFont API Client

/// Low-level API client for CoeFont
public actor CoeFontAPIClient {
    private let config: CoeFontConfig
    private let session: URLSession
    private var rateLimitTokens: Int
    private var lastTokenRefill: Date

    public init(config: CoeFontConfig) {
        self.config = config
        self.session = URLSession.shared
        self.rateLimitTokens = config.rateLimit
        self.lastTokenRefill = Date()
    }

    // MARK: - Authentication

    /// Generate HMAC-SHA256 signature for authentication
    public func generateSignature(timestamp: String, body: Data) -> String {
        let message = timestamp + String(data: body, encoding: .utf8)!
        let key = SymmetricKey(data: Data(config.clientSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Text-to-Speech

    /// Synthesize text to audio
    public func synthesize(
        text: String,
        coefontID: String,
        options: CoeFontSynthesisOptions = .default
    ) async throws -> Data {
        // Check rate limit
        try await checkRateLimit()

        // Validate text length
        guard text.count <= config.maxCharacters else {
            throw CoeFontError.textTooLong(maxCharacters: config.maxCharacters)
        }

        // Build request body
        let requestBody = SynthesisRequest(
            coefont: coefontID,
            text: text,
            speed: options.speed,
            pitch: options.pitch,
            kuten: options.intonation,
            volume: options.volume,
            format: options.format.rawValue
        )

        let bodyData = try JSONEncoder().encode(requestBody)

        // Build request
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signature = generateSignature(timestamp: timestamp, body: bodyData)

        var request = URLRequest(url: URL(string: "\(config.baseURL)/v2/text2speech")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.accessKey, forHTTPHeaderField: "X-Coefont-Access-Key")
        request.setValue(timestamp, forHTTPHeaderField: "X-Coefont-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Coefont-Signature")
        request.httpBody = bodyData

        // Execute request
        let (data, response) = try await session.data(for: request)

        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoeFontError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            throw CoeFontError.authenticationFailed
        case 429:
            throw CoeFontError.rateLimitExceeded
        case 400..<500:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw CoeFontError.apiError(
                code: httpResponse.statusCode,
                message: errorResponse?.message ?? "Unknown error"
            )
        default:
            throw CoeFontError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    /// Get available voices
    public func getAvailableVoices(language: String? = nil) async throws -> [CoeFontVoice] {
        try await checkRateLimit()

        var urlComponents = URLComponents(string: "\(config.baseURL)/v2/coefonts")!
        if let language = language {
            urlComponents.queryItems = [URLQueryItem(name: "language", value: language)]
        }

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signature = generateSignature(timestamp: timestamp, body: Data())

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue(config.accessKey, forHTTPHeaderField: "X-Coefont-Access-Key")
        request.setValue(timestamp, forHTTPHeaderField: "X-Coefont-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Coefont-Signature")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CoeFontError.invalidResponse
        }

        let voicesResponse = try JSONDecoder().decode(VoicesResponse.self, from: data)
        return voicesResponse.coefonts
    }

    // MARK: - Rate Limiting

    private func checkRateLimit() async throws {
        let now = Date()
        let timeSinceRefill = now.timeIntervalSince(lastTokenRefill)

        // Refill tokens every minute
        if timeSinceRefill >= 60 {
            rateLimitTokens = config.rateLimit
            lastTokenRefill = now
        }

        guard rateLimitTokens > 0 else {
            let waitTime = 60 - timeSinceRefill
            throw CoeFontError.rateLimitExceeded
        }

        rateLimitTokens -= 1
    }

    // MARK: - Request/Response Models

    private struct SynthesisRequest: Codable {
        let coefont: String
        let text: String
        let speed: Float
        let pitch: Float
        let kuten: Float
        let volume: Float
        let format: String
    }

    private struct VoicesResponse: Codable {
        let coefonts: [CoeFontVoice]
    }

    private struct ErrorResponse: Codable {
        let message: String
        let code: String?
    }
}

// MARK: - CoeFont TTS Service

/// CoeFont-based TTS service
public actor CoeFontTTSService: TTSServiceProtocol {
    public let provider: VoiceProvider = .coeFont

    private let apiClient: CoeFontAPIClient
    private let audioPlayer: AudioPlayerManager
    private var cachedVoices: [String: [CoeFontVoice]] = [:]
    public private(set) var isSpeaking: Bool = false

    public init(config: CoeFontConfig) {
        self.apiClient = CoeFontAPIClient(config: config)
        self.audioPlayer = AudioPlayerManager()
    }

    // MARK: - TTSServiceProtocol

    public func synthesize(_ text: String, voice: VoiceOption) async throws -> Data {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Data()
        }

        return try await apiClient.synthesize(
            text: text,
            coefontID: voice.id,
            options: .default
        )
    }

    public func streamSynthesize(_ text: String, voice: VoiceOption) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // CoeFont doesn't support streaming, so we synthesize chunks
                    let chunks = splitTextForStreaming(text)

                    for chunk in chunks {
                        let data = try await synthesize(chunk, voice: voice)
                        continuation.yield(data)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func play(_ data: Data) async throws {
        isSpeaking = true
        defer { isSpeaking = false }

        try await audioPlayer.play(data)
    }

    public func stopPlayback() async {
        await audioPlayer.stop()
        isSpeaking = false
    }

    public func speak(_ text: String, voice: VoiceOption) async throws {
        let data = try await synthesize(text, voice: voice)
        try await play(data)
    }

    public func availableVoices(for language: SupportedLanguage) async -> [VoiceOption] {
        // Return cached voices or fetch from API
        let languageCode = language.languageCode
        if let voices = cachedVoices[languageCode] {
            return voices.compactMap { $0.toVoiceOption() }
        }

        // Try to fetch from API
        if let voices = try? await fetchVoices(for: language) {
            return voices
        }

        return []
    }

    public func defaultVoice(for language: SupportedLanguage) async -> VoiceOption? {
        let voices = await availableVoices(for: language)
        return voices.first
    }

    // MARK: - Extended Methods

    /// Fetch voices from API and update cache
    public func fetchVoices(for language: SupportedLanguage) async throws -> [VoiceOption] {
        let languageCode = language.languageCode
        let voices = try await apiClient.getAvailableVoices(language: languageCode)

        cachedVoices[languageCode] = voices

        return voices.compactMap { $0.toVoiceOption() }
    }

    /// Synthesize with custom options
    public func synthesize(
        _ text: String,
        coefontID: String,
        options: CoeFontSynthesisOptions
    ) async throws -> Data {
        try await apiClient.synthesize(
            text: text,
            coefontID: coefontID,
            options: options
        )
    }

    // MARK: - Private Methods

    private func splitTextForStreaming(_ text: String) -> [String] {
        // Split by sentence for streaming effect
        let sentenceEnders = CharacterSet(charactersIn: "。.!?！？")
        var chunks: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if char.unicodeScalars.allSatisfy({ sentenceEnders.contains($0) }) {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }
}

// MARK: - CoeFont Error

public enum CoeFontError: LocalizedError, Sendable {
    case authenticationFailed
    case rateLimitExceeded
    case textTooLong(maxCharacters: Int)
    case voiceNotFound(id: String)
    case invalidResponse
    case apiError(code: Int, message: String)
    case serverError(statusCode: Int)
    case playbackFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "CoeFont authentication failed. Check your API credentials."
        case .rateLimitExceeded:
            return "CoeFont rate limit exceeded. Please wait before making more requests."
        case .textTooLong(let max):
            return "Text exceeds maximum length of \(max) characters."
        case .voiceNotFound(let id):
            return "CoeFont voice not found: \(id)"
        case .invalidResponse:
            return "Invalid response from CoeFont API"
        case .apiError(let code, let message):
            return "CoeFont API error (\(code)): \(message)"
        case .serverError(let statusCode):
            return "CoeFont server error: \(statusCode)"
        case .playbackFailed(let reason):
            return "Audio playback failed: \(reason)"
        }
    }
}

// MARK: - Audio Player Manager

/// Manages audio playback for CoeFont synthesized audio
private actor AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?

    func play(_ data: Data) async throws {
        do {
            // Configure audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()

            return try await withCheckedThrowingContinuation { continuation in
                let delegate = AudioPlayerDelegate {
                    continuation.resume()
                } onError: { error in
                    continuation.resume(throwing: error)
                }

                objc_setAssociatedObject(
                    audioPlayer!,
                    "audioPlayerDelegate",
                    delegate,
                    .OBJC_ASSOCIATION_RETAIN
                )

                audioPlayer?.delegate = delegate
                audioPlayer?.play()
            }
        } catch {
            throw CoeFontError.playbackFailed(reason: error.localizedDescription)
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - Audio Player Delegate

private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    private let onFinish: () -> Void
    private let onError: (Error) -> Void

    init(onFinish: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.onFinish = onFinish
        self.onError = onError
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            onFinish()
        } else {
            onError(CoeFontError.playbackFailed(reason: "Playback did not complete successfully"))
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onError(error ?? CoeFontError.playbackFailed(reason: "Decode error"))
    }
}
