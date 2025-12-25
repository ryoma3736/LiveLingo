import Foundation
import AVFoundation
import Combine

// MARK: - Pause Detection Configuration

/// Configuration for pause detection thresholds
public struct PauseDetectionConfig: Sendable {
    /// Short pause threshold (comma-equivalent) in seconds
    public let shortPauseThreshold: TimeInterval

    /// Long pause threshold (period-equivalent) in seconds
    public let longPauseThreshold: TimeInterval

    /// Silence threshold in decibels
    public let silenceThresholdDB: Float

    /// Minimum speech duration before pause detection activates
    public let minSpeechDuration: TimeInterval

    public init(
        shortPauseThreshold: TimeInterval = 0.3,
        longPauseThreshold: TimeInterval = 0.8,
        silenceThresholdDB: Float = -40.0,
        minSpeechDuration: TimeInterval = 0.1
    ) {
        self.shortPauseThreshold = shortPauseThreshold
        self.longPauseThreshold = longPauseThreshold
        self.silenceThresholdDB = silenceThresholdDB
        self.minSpeechDuration = minSpeechDuration
    }

    public static let `default` = PauseDetectionConfig()

    public static let sensitive = PauseDetectionConfig(
        shortPauseThreshold: 0.2,
        longPauseThreshold: 0.5,
        silenceThresholdDB: -35.0
    )

    public static let relaxed = PauseDetectionConfig(
        shortPauseThreshold: 0.5,
        longPauseThreshold: 1.2,
        silenceThresholdDB: -45.0
    )
}

// MARK: - Pause Type

/// Types of detected pauses
public enum PauseType: Sendable, Equatable {
    /// Short pause - equivalent to comma, brief hesitation
    case short

    /// Long pause - equivalent to period, sentence end
    case long

    /// Utterance end - speaker finished talking
    case utteranceEnd

    public var description: String {
        switch self {
        case .short: return "Short Pause (,)"
        case .long: return "Long Pause (.)"
        case .utteranceEnd: return "Utterance End"
        }
    }
}

// MARK: - Pause Detection Result

/// Result of pause detection analysis
public struct PauseDetectionResult: Sendable {
    public let pauseType: PauseType?
    public let silenceDuration: TimeInterval
    public let currentDB: Float
    public let isSpeaking: Bool
    public let timestamp: Date

    public init(
        pauseType: PauseType?,
        silenceDuration: TimeInterval,
        currentDB: Float,
        isSpeaking: Bool,
        timestamp: Date = Date()
    ) {
        self.pauseType = pauseType
        self.silenceDuration = silenceDuration
        self.currentDB = currentDB
        self.isSpeaking = isSpeaking
        self.timestamp = timestamp
    }
}

// MARK: - Pause Detector

/// Real-time pause detector for speech recognition
public actor PauseDetector: PauseDetectorProtocol {
    // MARK: - Properties

    private var config: PauseDetectionConfig
    private var lastSpeechTime: Date = Date()
    private var lastPauseType: PauseType?
    private var isSpeaking: Bool = false
    private var speechStartTime: Date?

    private nonisolated(unsafe) let resultSubject = PassthroughSubject<PauseDetectionResult, Never>()

    public nonisolated var pauseThreshold: TimeInterval {
        get { 0.8 }
        set { }
    }

    // MARK: - Public Stream

    public nonisolated var pauseStream: AnyPublisher<PauseDetectionResult, Never> {
        resultSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(config: PauseDetectionConfig = .default) {
        self.config = config
    }

    // MARK: - Configuration

    public func updateConfig(_ config: PauseDetectionConfig) {
        self.config = config
    }

    // MARK: - PauseDetectorProtocol

    public nonisolated func detectPause(silenceDuration: TimeInterval) -> Bool {
        return silenceDuration >= 0.8
    }

    // MARK: - Audio Analysis

    /// Analyze audio buffer for pause detection
    /// - Parameter buffer: Audio PCM buffer to analyze
    /// - Returns: Pause detection result
    public func analyzeBuffer(_ buffer: AVAudioPCMBuffer) -> PauseDetectionResult {
        let db = calculateDecibels(from: buffer)
        let now = Date()

        let isSilent = db < config.silenceThresholdDB

        if isSilent {
            // Silence detected
            if isSpeaking {
                // Was speaking, now silent - potential pause
                let silenceDuration = now.timeIntervalSince(lastSpeechTime)
                let pauseType = determinePauseType(silenceDuration: silenceDuration)

                if pauseType != lastPauseType {
                    lastPauseType = pauseType

                    let result = PauseDetectionResult(
                        pauseType: pauseType,
                        silenceDuration: silenceDuration,
                        currentDB: db,
                        isSpeaking: false,
                        timestamp: now
                    )

                    resultSubject.send(result)
                    return result
                }

                return PauseDetectionResult(
                    pauseType: nil,
                    silenceDuration: silenceDuration,
                    currentDB: db,
                    isSpeaking: false,
                    timestamp: now
                )
            } else {
                // Still silent
                let silenceDuration = now.timeIntervalSince(lastSpeechTime)
                return PauseDetectionResult(
                    pauseType: nil,
                    silenceDuration: silenceDuration,
                    currentDB: db,
                    isSpeaking: false,
                    timestamp: now
                )
            }
        } else {
            // Speech detected
            if !isSpeaking {
                // Started speaking
                speechStartTime = now
                isSpeaking = true
            }

            lastSpeechTime = now
            lastPauseType = nil

            return PauseDetectionResult(
                pauseType: nil,
                silenceDuration: 0,
                currentDB: db,
                isSpeaking: true,
                timestamp: now
            )
        }
    }

    /// Analyze raw audio data for pause detection
    /// - Parameter data: Raw audio data
    /// - Returns: Pause detection result
    public func analyzeData(_ data: Data) -> PauseDetectionResult {
        let db = calculateDecibels(from: data)
        let now = Date()

        let isSilent = db < config.silenceThresholdDB
        let silenceDuration = isSilent ? now.timeIntervalSince(lastSpeechTime) : 0

        if !isSilent {
            lastSpeechTime = now
            isSpeaking = true
            lastPauseType = nil
        } else if isSpeaking {
            isSpeaking = false
        }

        let pauseType = isSilent ? determinePauseType(silenceDuration: silenceDuration) : nil

        if pauseType != nil && pauseType != lastPauseType {
            lastPauseType = pauseType
            let result = PauseDetectionResult(
                pauseType: pauseType,
                silenceDuration: silenceDuration,
                currentDB: db,
                isSpeaking: !isSilent,
                timestamp: now
            )
            resultSubject.send(result)
            return result
        }

        return PauseDetectionResult(
            pauseType: nil,
            silenceDuration: silenceDuration,
            currentDB: db,
            isSpeaking: !isSilent,
            timestamp: now
        )
    }

    // MARK: - Reset

    public func reset() {
        lastSpeechTime = Date()
        lastPauseType = nil
        isSpeaking = false
        speechStartTime = nil
    }

    // MARK: - Private Methods

    private func determinePauseType(silenceDuration: TimeInterval) -> PauseType? {
        if silenceDuration >= config.longPauseThreshold * 2 {
            return .utteranceEnd
        } else if silenceDuration >= config.longPauseThreshold {
            return .long
        } else if silenceDuration >= config.shortPauseThreshold {
            return .short
        }
        return nil
    }

    private func calculateDecibels(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else {
            return -100.0
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return -100.0 }

        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 1e-10))

        return db
    }

    private func calculateDecibels(from data: Data) -> Float {
        guard data.count >= 2 else { return -100.0 }

        let samples = data.withUnsafeBytes { buffer -> [Int16] in
            let pointer = buffer.bindMemory(to: Int16.self)
            return Array(pointer)
        }

        guard !samples.isEmpty else { return -100.0 }

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let rms = sqrt(sum / Float(samples.count))
        let db = 20 * log10(max(rms, 1e-10))

        return db
    }
}

// MARK: - Voice Activity Detector

/// Voice Activity Detection implementation
public actor VoiceActivityDetector: VADProtocol {
    private var _silenceThreshold: Float = -40.0
    private var _minSpeechDuration: TimeInterval = 0.1

    private var speechStartTime: Date?
    private var lastActivityTime: Date = Date()

    public nonisolated var silenceThreshold: Float {
        get { -40.0 }
        set { }
    }

    public nonisolated var minSpeechDuration: TimeInterval {
        get { 0.1 }
        set { }
    }

    public init(silenceThreshold: Float = -40.0, minSpeechDuration: TimeInterval = 0.1) {
        self._silenceThreshold = silenceThreshold
        self._minSpeechDuration = minSpeechDuration
    }

    public nonisolated func detectVoiceActivity(in buffer: Data) -> Bool {
        guard buffer.count >= 2 else { return false }

        let samples = buffer.withUnsafeBytes { ptr -> [Int16] in
            let pointer = ptr.bindMemory(to: Int16.self)
            return Array(pointer)
        }

        guard !samples.isEmpty else { return false }

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }

        let rms = sqrt(sum / Float(samples.count))
        let db = 20 * log10(max(rms, 1e-10))

        return db >= -40.0
    }

    public func updateThresholds(silence: Float, minDuration: TimeInterval) {
        _silenceThreshold = silence
        _minSpeechDuration = minDuration
    }

    public func reset() {
        speechStartTime = nil
        lastActivityTime = Date()
    }
}
