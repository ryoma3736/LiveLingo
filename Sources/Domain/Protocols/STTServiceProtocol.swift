import Foundation

/// Protocol for Speech-to-Text services
public protocol STTServiceProtocol: Sendable {
    /// Start speech recognition for a given language
    /// - Parameter language: The language to recognize
    /// - Returns: An async stream of recognition results
    func startRecognition(language: SupportedLanguage) async throws -> AsyncStream<RecognitionResult>

    /// Stop the current recognition session
    func stopRecognition() async

    /// Check if speech recognition is available
    var isAvailable: Bool { get }

    /// Check if currently recognizing
    var isRecognizing: Bool { get }

    /// Supported languages for this STT service
    var supportedLanguages: [SupportedLanguage] { get }
}

/// Protocol for Voice Activity Detection
public protocol VADProtocol: Sendable {
    /// Detect if voice activity is present in the audio buffer
    /// - Parameter buffer: The audio buffer to analyze
    /// - Returns: true if voice activity detected
    func detectVoiceActivity(in buffer: Data) -> Bool

    /// The silence threshold in decibels
    var silenceThreshold: Float { get set }

    /// Minimum speech duration to trigger detection
    var minSpeechDuration: TimeInterval { get set }
}

/// Protocol for Pause Detection
public protocol PauseDetectorProtocol: Sendable {
    /// Detect if a pause has occurred
    /// - Parameter silenceDuration: Duration of silence in seconds
    /// - Returns: true if pause detected
    func detectPause(silenceDuration: TimeInterval) -> Bool

    /// The pause threshold in seconds (default: 0.8s)
    var pauseThreshold: TimeInterval { get set }
}

/// Protocol for Speaker Diarization
public protocol SpeakerDiarizerProtocol: Sendable {
    /// Identify the speaker for an audio segment
    /// - Parameter segment: The audio segment to analyze
    /// - Returns: The identified speaker
    func identifySpeaker(for segment: Data) async -> SpeakerID

    /// Reset speaker profiles
    func resetProfiles()
}
