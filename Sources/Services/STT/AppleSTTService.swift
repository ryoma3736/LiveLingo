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
        guard !isRecognizing else {
            throw LiveLingoError.sttAlreadyRecognizing
        }

        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
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
        recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition

        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
        }

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
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecognizing = false
    }

    // MARK: - Private Methods

    private func setupAudioEngine(_ engine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest) async throws {
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            throw LiveLingoError.audioSessionConfigurationFailed(reason: "Invalid audio format")
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            throw LiveLingoError.audioSessionActivationFailed(reason: error.localizedDescription)
        }
    }

    private func startRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        language: SupportedLanguage,
        continuation: AsyncStream<RecognitionResult>.Continuation
    ) async throws {
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                // Handle specific errors
                if let nsError = error as NSError? {
                    switch nsError.code {
                    case 1110: // "No speech detected"
                        // Continue silently
                        return
                    case 301: // "Recognition error"
                        Task { await self.stopRecognition() }
                        continuation.finish()
                        return
                    default:
                        break
                    }
                }

                Task { await self.stopRecognition() }
                continuation.finish()
                return
            }

            guard let result = result else { return }

            let recognitionResult = RecognitionResult(
                text: result.bestTranscription.formattedString,
                isFinal: result.isFinal,
                speakerID: .speaker1,
                confidence: self.calculateConfidence(from: result),
                language: language,
                timestamp: Date(),
                segments: self.extractSegments(from: result)
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
    public var segments: [RecognitionSegment]?

    init(
        text: String,
        isFinal: Bool,
        speakerID: SpeakerID = .unknown,
        confidence: Float = 0,
        language: SupportedLanguage,
        timestamp: Date = Date(),
        segments: [RecognitionSegment]? = nil
    ) {
        self.init(
            text: text,
            isFinal: isFinal,
            speakerID: speakerID,
            confidence: confidence,
            language: language
        )
    }
}
