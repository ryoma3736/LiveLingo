import Foundation
import Speech
import AVFoundation

// MARK: - Apple STT Service

/// Apple's Speech Recognition service implementation
public actor AppleSTTService: STTServiceProtocol {
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentLanguage: SupportedLanguage?

    public private(set) var isRecognizing: Bool = false
    public var isAvailable: Bool {
        get async {
            guard let recognizer = recognizer else { return false }
            return recognizer.isAvailable
        }
    }

    public var supportedLanguages: [SupportedLanguage] {
        SupportedLanguage.allCases.filter { language in
            SFSpeechRecognizer(locale: language.locale) != nil
        }
    }

    public init() {}

    // MARK: - Recognition

    public func startRecognition(language: SupportedLanguage) async throws -> AsyncStream<RecognitionResult> {
        print("[STT] startRecognition called for language: \(language.rawValue)")

        guard !isRecognizing else {
            print("[STT] Already recognizing, throwing error")
            throw LiveLingoError.sttAlreadyRecognizing
        }

        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        print("[STT] Authorization status: \(status.rawValue)")
        guard status == .authorized else {
            print("[STT] Permission denied, status: \(status.rawValue)")
            throw LiveLingoError.sttPermissionDenied
        }

        // Initialize recognizer for the language
        guard let speechRecognizer = SFSpeechRecognizer(locale: language.locale) else {
            throw LiveLingoError.sttNotAvailable(reason: "Language \(language.nativeName) is not supported")
        }

        guard speechRecognizer.isAvailable else {
            throw LiveLingoError.sttNotAvailable(reason: "Speech recognition is not available")
        }

        self.recognizer = speechRecognizer
        self.currentLanguage = language
        self.audioEngine = AVAudioEngine()
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest,
              let audioEngine = audioEngine else {
            throw LiveLingoError.sttNotAvailable(reason: "Failed to initialize audio engine")
        }

        // Configure recognition request
        recognitionRequest.shouldReportPartialResults = true

        // Force server-based recognition to avoid local service issues (error 1101)
        recognitionRequest.requiresOnDeviceRecognition = false
        print("[STT] Using server-based recognition (on-device: \(speechRecognizer.supportsOnDeviceRecognition))")

        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }

        // Set task hint for better recognition
        recognitionRequest.taskHint = .dictation

        isRecognizing = true

        return AsyncStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }

            Task {
                do {
                    try await self.setupAudioEngine(audioEngine, request: recognitionRequest)
                    try await self.startRecognitionTask(
                        recognizer: speechRecognizer,
                        request: recognitionRequest,
                        language: language,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.stopRecognition()
                }
            }
        }
    }

    public func stopRecognition() async {
        print("[STT] Stopping recognition...")

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecognizing = false

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("[STT] Audio session deactivated")
        } catch {
            print("[STT] Failed to deactivate audio session: \(error)")
        }

        print("[STT] Recognition stopped")
    }

    // MARK: - Private Methods

    private func setupAudioEngine(_ engine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest) async throws {
        // Configure audio session for speech recognition
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use .playAndRecord to support both STT and TTS
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[STT] Audio session configured (category: playAndRecord)")
        } catch {
            print("[STT] Audio session configuration failed: \(error)")
            throw LiveLingoError.audioSessionConfigurationFailed(underlying: error)
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            throw LiveLingoError.audioSessionConfigurationFailed(underlying: NSError(domain: "AppleSTTService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio format"]))
        }

        print("[STT] Audio format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount) channels")

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()

        do {
            try engine.start()
            print("[STT] Audio engine started successfully")
        } catch {
            print("[STT] Audio engine start failed: \(error)")
            throw LiveLingoError.audioSessionActivationFailed(underlying: error)
        }
    }

    private func startRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        language: SupportedLanguage,
        continuation: AsyncStream<RecognitionResult>.Continuation
    ) async throws {
        print("[STT] Starting recognition task...")
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                // Handle specific errors
                if let nsError = error as NSError? {
                    print("[STT] Recognition error: \(nsError.domain) code=\(nsError.code) - \(nsError.localizedDescription)")

                    switch nsError.code {
                    case 1110: // "No speech detected"
                        // Continue silently
                        print("[STT] No speech detected, continuing...")
                        return
                    case 1101: // Service unavailable or network issue
                        print("[STT] Error 1101: Speech recognition service unavailable. Check network connection.")
                        // Continue - don't stop, as this might be temporary
                        return
                    case 301: // "Recognition error"
                        print("[STT] Error 301: Recognition error, stopping...")
                        Task { await self.stopRecognition() }
                        continuation.finish()
                        return
                    case 203: // "Operation cancelled"
                        print("[STT] Error 203: Operation cancelled")
                        return
                    case 209: // "Session ended"
                        print("[STT] Error 209: Session ended")
                        return
                    default:
                        print("[STT] Unhandled error code: \(nsError.code)")
                        break
                    }
                }

                Task { await self.stopRecognition() }
                continuation.finish()
                return
            }

            guard let result = result else {
                print("[STT] Received nil result (waiting for speech...)")
                return
            }

            print("[STT] Recognition result: '\(result.bestTranscription.formattedString)' isFinal=\(result.isFinal)")

            let recognitionResult = RecognitionResult(
                text: result.bestTranscription.formattedString,
                isFinal: result.isFinal,
                speakerID: .speaker1,
                confidence: self.calculateConfidence(from: result),
                language: language,
                timestamp: Date()
            )

            continuation.yield(recognitionResult)

            if result.isFinal {
                Task { await self.stopRecognition() }
                continuation.finish()
            }
        }
    }

    private func calculateConfidence(from result: SFSpeechRecognitionResult) -> Float {
        let segments = result.bestTranscription.segments
        guard !segments.isEmpty else { return 0 }

        let totalConfidence = segments.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(segments.count)
    }

    private func extractSegments(from result: SFSpeechRecognitionResult) -> [RecognitionSegment] {
        result.bestTranscription.segments.map { segment in
            RecognitionSegment(
                text: segment.substring,
                startTime: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence
            )
        }
    }
}

// MARK: - Recognition Segment

/// Individual segment of recognized speech
public struct RecognitionSegment: Sendable {
    public let text: String
    public let startTime: TimeInterval
    public let duration: TimeInterval
    public let confidence: Float

    public init(text: String, startTime: TimeInterval, duration: TimeInterval, confidence: Float) {
        self.text = text
        self.startTime = startTime
        self.duration = duration
        self.confidence = confidence
    }
}

// MARK: - Enhanced Recognition Result

extension RecognitionResult {
    /// Segments are not stored in RecognitionResult - use dedicated segment tracking
    public var segments: [RecognitionSegment]? { nil }
}
