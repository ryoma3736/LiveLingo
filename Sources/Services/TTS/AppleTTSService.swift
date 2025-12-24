import Foundation
import AVFoundation

// MARK: - Apple TTS Service

/// Apple's AVSpeechSynthesizer-based TTS service
public actor AppleTTSService: TTSServiceProtocol {
    public let provider: VoiceProvider = .system

    private let synthesizer: AVSpeechSynthesizer
    private var delegate: TTSSynthesizerDelegate?
    public private(set) var isSpeaking: Bool = false

    private var currentUtterance: AVSpeechUtterance?
    private var playbackContinuation: CheckedContinuation<Void, Error>?

    public init() {
        self.synthesizer = AVSpeechSynthesizer()
        setupDelegate()
    }

    private func setupDelegate() {
        let delegate = TTSSynthesizerDelegate { [weak self] in
            Task { await self?.handleSpeechDidFinish() }
        } onError: { [weak self] error in
            Task { await self?.handleSpeechError(error) }
        }
        self.delegate = delegate
        self.synthesizer.delegate = delegate
    }

    // MARK: - Synthesis

    public func synthesize(_ text: String, voice: VoiceOption) async throws -> Data {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Data()
        }

        // AVSpeechSynthesizer doesn't support direct audio data export
        // For iOS, we use the speak method instead
        // This method is provided for API compatibility
        throw LiveLingoError.ttsSynthesisFailed(reason: "Direct synthesis to data not supported by AVSpeechSynthesizer")
    }

    public func streamSynthesize(_ text: String, voice: VoiceOption) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            // AVSpeechSynthesizer doesn't support streaming synthesis
            continuation.finish(throwing: LiveLingoError.ttsSynthesisFailed(
                reason: "Streaming synthesis not supported by system TTS"
            ))
        }
    }

    public func speak(_ text: String, voice: VoiceOption) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Stop any current speech
        if isSpeaking {
            stopPlayback()
        }

        let utterance = createUtterance(text: text, voice: voice)
        currentUtterance = utterance
        isSpeaking = true

        return try await withCheckedThrowingContinuation { continuation in
            playbackContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    public func play(_ data: Data) async throws {
        // Not applicable for AVSpeechSynthesizer
        throw LiveLingoError.ttsPlaybackFailed(reason: "Direct audio playback not supported")
    }

    public func stopPlayback() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    public func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    public func resume() {
        synthesizer.continueSpeaking()
    }

    // MARK: - Voices

    public func availableVoices(for language: SupportedLanguage) -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: language.languageCode) }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: language,
                    provider: .system,
                    quality: mapVoiceQuality(voice.quality),
                    gender: mapGender(from: voice),
                    isDefault: voice.identifier == AVSpeechSynthesisVoice(language: language.rawValue)?.identifier
                )
            }
            .sorted { v1, v2 in
                // Sort by quality (premium first), then by name
                if v1.quality != v2.quality {
                    return (v1.quality?.rawValue ?? 0) > (v2.quality?.rawValue ?? 0)
                }
                return v1.name < v2.name
            }
    }

    public func defaultVoice(for language: SupportedLanguage) -> VoiceOption? {
        guard let voice = AVSpeechSynthesisVoice(language: language.rawValue) else {
            return nil
        }

        return VoiceOption(
            id: voice.identifier,
            name: voice.name,
            language: language,
            provider: .system,
            isDefault: true
        )
    }

    // MARK: - Private Methods

    private func createUtterance(text: String, voice: VoiceOption) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)

        if let avVoice = AVSpeechSynthesisVoice(identifier: voice.id) {
            utterance.voice = avVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: voice.language.rawValue)
        }

        // Configure speech parameters
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        return utterance
    }

    private func mapVoiceQuality(_ quality: AVSpeechSynthesisVoiceQuality) -> VoiceQuality? {
        switch quality {
        case .default:
            return .standard
        case .enhanced:
            return .enhanced
        case .premium:
            return .premium
        @unknown default:
            return .standard
        }
    }

    private func mapGender(from voice: AVSpeechSynthesisVoice) -> VoiceGender? {
        if #available(iOS 17.0, *) {
            switch voice.gender {
            case .female:
                return .female
            case .male:
                return .male
            case .unspecified:
                return nil
            @unknown default:
                return nil
            }
        }
        return nil
    }

    private func handleSpeechDidFinish() {
        isSpeaking = false
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    private func handleSpeechError(_ error: Error) {
        isSpeaking = false
        playbackContinuation?.resume(throwing: error)
        playbackContinuation = nil
    }
}

// MARK: - TTS Synthesizer Delegate

private final class TTSSynthesizerDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
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

// MARK: - Voice Quality

public enum VoiceQuality: Int, Sendable, Codable {
    case standard = 0
    case enhanced = 1
    case premium = 2

    public var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        }
    }
}

// MARK: - Voice Gender

public enum VoiceGender: String, Sendable, Codable {
    case male
    case female

    public var displayName: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        }
    }
}

// MARK: - Extended VoiceOption

extension VoiceOption {
    public var quality: VoiceQuality? { nil }
    public var gender: VoiceGender? { nil }

    init(
        id: String,
        name: String,
        language: SupportedLanguage,
        provider: VoiceProvider,
        quality: VoiceQuality? = nil,
        gender: VoiceGender? = nil,
        isDefault: Bool = false
    ) {
        self.init(id: id, name: name, language: language, provider: provider, isDefault: isDefault)
    }
}
