import Foundation
import AVFoundation

/// Protocol for Text-to-Speech services
public protocol TTSServiceProtocol: Sendable {
    /// Synthesize text to audio
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voice: The voice to use
    /// - Returns: The synthesized audio data
    func synthesize(_ text: String, voice: VoiceOption) async throws -> Data

    /// Stream synthesize text to audio for real-time playback
    /// - Parameters:
    ///   - text: The text to synthesize
    ///   - voice: The voice to use
    /// - Returns: An async stream of audio chunks
    func streamSynthesize(_ text: String, voice: VoiceOption) -> AsyncThrowingStream<Data, Error>

    /// Play synthesized audio
    /// - Parameter data: The audio data to play
    func play(_ data: Data) async throws

    /// Stop playback
    func stopPlayback()

    /// Available voices for a language
    func availableVoices(for language: SupportedLanguage) -> [VoiceOption]

    /// The provider type for this service
    var provider: VoiceProvider { get }

    /// Check if currently speaking
    var isSpeaking: Bool { get }
}

/// Protocol for Audio Queue Management
public protocol AudioQueueProtocol: Sendable {
    /// Enqueue audio data for playback
    func enqueue(_ data: Data)

    /// Start playback of queued audio
    func startPlayback() async

    /// Stop playback and clear queue
    func stopPlayback()

    /// Pause playback
    func pause()

    /// Resume playback
    func resume()

    /// Number of segments to pre-buffer
    var prebufferCount: Int { get set }

    /// Check if queue is empty
    var isEmpty: Bool { get }

    /// Check if currently playing
    var isPlaying: Bool { get }
}

/// Protocol for Voice Selection
public protocol VoiceSelectionProtocol: Sendable {
    /// Get all available voices
    func getAllVoices() async -> [VoiceOption]

    /// Get available voices for a language
    func getVoices(for language: SupportedLanguage) async -> [VoiceOption]

    /// Get the default voice for a language
    func getDefaultVoice(for language: SupportedLanguage) async -> VoiceOption?

    /// Set the preferred voice for a language
    func setPreferredVoice(_ voice: VoiceOption, for language: SupportedLanguage)

    /// Get the preferred voice for a language
    func getPreferredVoice(for language: SupportedLanguage) -> VoiceOption?
}
