import Foundation
import AVFoundation
import Accelerate

// MARK: - Speaker Profile

/// Audio features extracted from speaker's voice
public struct SpeakerProfile: Sendable {
    /// Speaker identifier
    public let speakerID: SpeakerID

    /// MFCC (Mel-Frequency Cepstral Coefficients) feature vector
    public let mfccFeatures: [Float]

    /// Pitch (F0) characteristics
    public let pitchMean: Float
    public let pitchVariance: Float

    /// Energy characteristics
    public let energyMean: Float
    public let energyVariance: Float

    /// Number of samples used to build this profile
    public let sampleCount: Int

    /// Last updated timestamp
    public let lastUpdated: Date

    public init(
        speakerID: SpeakerID,
        mfccFeatures: [Float],
        pitchMean: Float,
        pitchVariance: Float,
        energyMean: Float,
        energyVariance: Float,
        sampleCount: Int,
        lastUpdated: Date = Date()
    ) {
        self.speakerID = speakerID
        self.mfccFeatures = mfccFeatures
        self.pitchMean = pitchMean
        self.pitchVariance = pitchVariance
        self.energyMean = energyMean
        self.energyVariance = energyVariance
        self.sampleCount = sampleCount
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Speaker Diarization Configuration

public struct SpeakerDiarizationConfig: Sendable {
    /// Minimum audio segment length for analysis (seconds)
    public let minSegmentDuration: TimeInterval

    /// Similarity threshold for speaker matching (0.0 - 1.0)
    public let similarityThreshold: Float

    /// Number of MFCC coefficients to use
    public let mfccCoefficients: Int

    /// Frame size for audio analysis (samples)
    public let frameSize: Int

    /// Hop size between frames (samples)
    public let hopSize: Int

    /// Sample rate expected
    public let sampleRate: Float

    /// Maximum number of speaker profiles to maintain
    public let maxProfiles: Int

    public init(
        minSegmentDuration: TimeInterval = 0.5,
        similarityThreshold: Float = 0.75,
        mfccCoefficients: Int = 13,
        frameSize: Int = 1024,
        hopSize: Int = 512,
        sampleRate: Float = 16000,
        maxProfiles: Int = 2
    ) {
        self.minSegmentDuration = minSegmentDuration
        self.similarityThreshold = similarityThreshold
        self.mfccCoefficients = mfccCoefficients
        self.frameSize = frameSize
        self.hopSize = hopSize
        self.sampleRate = sampleRate
        self.maxProfiles = maxProfiles
    }

    public static let `default` = SpeakerDiarizationConfig()

    /// Configuration optimized for dual-speaker scenarios
    public static let dualSpeaker = SpeakerDiarizationConfig(
        minSegmentDuration: 0.3,
        similarityThreshold: 0.7,
        maxProfiles: 2
    )
}

// MARK: - Speaker Diarization Result

public struct DiarizationResult: Sendable {
    public let speakerID: SpeakerID
    public let confidence: Float
    public let isNewSpeaker: Bool
    public let timestamp: Date

    public init(
        speakerID: SpeakerID,
        confidence: Float,
        isNewSpeaker: Bool,
        timestamp: Date = Date()
    ) {
        self.speakerID = speakerID
        self.confidence = confidence
        self.isNewSpeaker = isNewSpeaker
        self.timestamp = timestamp
    }
}

// MARK: - Speaker Diarizer

/// Real-time speaker diarization for dual-speaker interpretation
public actor SpeakerDiarizer: SpeakerDiarizerProtocol {
    // MARK: - Properties

    private let config: SpeakerDiarizationConfig
    private var speakerProfiles: [SpeakerID: SpeakerProfile] = [:]
    private var lastSpeaker: SpeakerID = .unknown
    private var segmentBuffer: [Float] = []

    // MARK: - Initialization

    public init(config: SpeakerDiarizationConfig = .default) {
        self.config = config
    }

    // MARK: - SpeakerDiarizerProtocol

    /// Identify speaker from audio segment
    public func identifySpeaker(for segment: Data) async -> SpeakerID {
        let result = await analyzeSegment(segment)
        return result.speakerID
    }

    /// Reset all speaker profiles
    public nonisolated func resetProfiles() {
        Task { await _resetProfiles() }
    }

    private func _resetProfiles() {
        speakerProfiles.removeAll()
        lastSpeaker = .unknown
        segmentBuffer.removeAll()
    }

    // MARK: - Public Analysis Methods

    /// Analyze audio segment and identify speaker with detailed result
    public func analyzeSegment(_ segment: Data) async -> DiarizationResult {
        // Convert data to float samples
        let samples = convertToFloatSamples(segment)

        // Check minimum duration
        let duration = TimeInterval(samples.count) / TimeInterval(config.sampleRate)
        guard duration >= config.minSegmentDuration else {
            return DiarizationResult(
                speakerID: lastSpeaker,
                confidence: 0,
                isNewSpeaker: false
            )
        }

        // Extract features
        let features = extractFeatures(from: samples)

        // If no profiles exist, create first speaker
        if speakerProfiles.isEmpty {
            let profile = createProfile(speakerID: .speaker1, features: features)
            speakerProfiles[.speaker1] = profile
            lastSpeaker = .speaker1

            return DiarizationResult(
                speakerID: .speaker1,
                confidence: 1.0,
                isNewSpeaker: true
            )
        }

        // Find best matching speaker
        var bestMatch: (speakerID: SpeakerID, similarity: Float) = (.unknown, 0)

        for (speakerID, profile) in speakerProfiles {
            let similarity = calculateSimilarity(features: features, profile: profile)
            if similarity > bestMatch.similarity {
                bestMatch = (speakerID, similarity)
            }
        }

        // Check if matches existing speaker
        if bestMatch.similarity >= config.similarityThreshold {
            // Update profile with new sample
            if let existingProfile = speakerProfiles[bestMatch.speakerID] {
                speakerProfiles[bestMatch.speakerID] = updateProfile(
                    existingProfile,
                    with: features
                )
            }
            lastSpeaker = bestMatch.speakerID

            return DiarizationResult(
                speakerID: bestMatch.speakerID,
                confidence: bestMatch.similarity,
                isNewSpeaker: false
            )
        }

        // New speaker detected
        if speakerProfiles.count < config.maxProfiles {
            let newSpeakerID: SpeakerID = speakerProfiles[.speaker1] != nil ? .speaker2 : .speaker1
            let profile = createProfile(speakerID: newSpeakerID, features: features)
            speakerProfiles[newSpeakerID] = profile
            lastSpeaker = newSpeakerID

            return DiarizationResult(
                speakerID: newSpeakerID,
                confidence: 1.0,
                isNewSpeaker: true
            )
        }

        // Max profiles reached, assign to closest match
        lastSpeaker = bestMatch.speakerID
        return DiarizationResult(
            speakerID: bestMatch.speakerID,
            confidence: bestMatch.similarity,
            isNewSpeaker: false
        )
    }

    /// Analyze audio buffer (AVAudioPCMBuffer)
    public func analyzeBuffer(_ buffer: AVAudioPCMBuffer) async -> DiarizationResult {
        guard let channelData = buffer.floatChannelData?[0] else {
            return DiarizationResult(
                speakerID: lastSpeaker,
                confidence: 0,
                isNewSpeaker: false
            )
        }

        let frameLength = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            samples[i] = channelData[i]
        }

        // Convert to Data
        let data = samples.withUnsafeBufferPointer { buffer in
            Data(bytes: buffer.baseAddress!, count: buffer.count * MemoryLayout<Float>.size)
        }

        return await analyzeSegment(data)
    }

    /// Get current speaker profiles
    public func getProfiles() -> [SpeakerID: SpeakerProfile] {
        speakerProfiles
    }

    /// Get last identified speaker
    public func getLastSpeaker() -> SpeakerID {
        lastSpeaker
    }

    // MARK: - Private Methods

    private func convertToFloatSamples(_ data: Data) -> [Float] {
        // Assume 16-bit PCM audio
        let samples = data.withUnsafeBytes { buffer -> [Float] in
            let int16Pointer = buffer.bindMemory(to: Int16.self)
            return int16Pointer.map { Float($0) / Float(Int16.max) }
        }
        return samples
    }

    private func extractFeatures(from samples: [Float]) -> AudioFeatures {
        // Calculate energy
        let energy = calculateEnergy(samples)

        // Estimate pitch (simplified F0 estimation)
        let pitch = estimatePitch(samples)

        // Calculate simplified MFCC-like features
        let mfcc = calculateSimplifiedMFCC(samples)

        return AudioFeatures(
            mfcc: mfcc,
            pitchMean: pitch.mean,
            pitchVariance: pitch.variance,
            energyMean: energy.mean,
            energyVariance: energy.variance
        )
    }

    private func calculateEnergy(_ samples: [Float]) -> (mean: Float, variance: Float) {
        guard !samples.isEmpty else { return (0, 0) }

        let energies = stride(from: 0, to: samples.count - config.frameSize, by: config.hopSize).map { start -> Float in
            let frame = Array(samples[start..<start + config.frameSize])
            return frame.reduce(0) { $0 + $1 * $1 } / Float(config.frameSize)
        }

        let mean = energies.reduce(0, +) / Float(energies.count)
        let variance = energies.reduce(0) { $0 + pow($1 - mean, 2) } / Float(energies.count)

        return (mean, variance)
    }

    private func estimatePitch(_ samples: [Float]) -> (mean: Float, variance: Float) {
        guard samples.count >= config.frameSize else { return (0, 0) }

        // Simplified autocorrelation-based pitch estimation
        var pitches: [Float] = []

        for start in stride(from: 0, to: samples.count - config.frameSize, by: config.hopSize) {
            let frame = Array(samples[start..<start + config.frameSize])
            if let pitch = estimateFramePitch(frame) {
                pitches.append(pitch)
            }
        }

        guard !pitches.isEmpty else { return (200, 50) } // Default voice range

        let mean = pitches.reduce(0, +) / Float(pitches.count)
        let variance = pitches.reduce(0) { $0 + pow($1 - mean, 2) } / Float(pitches.count)

        return (mean, variance)
    }

    private func estimateFramePitch(_ frame: [Float]) -> Float? {
        // Simplified autocorrelation for pitch detection
        let minLag = Int(config.sampleRate / 400)  // Max F0 = 400 Hz
        let maxLag = Int(config.sampleRate / 80)   // Min F0 = 80 Hz

        guard maxLag < frame.count else { return nil }

        var maxCorr: Float = 0
        var bestLag = 0

        for lag in minLag..<min(maxLag, frame.count) {
            var corr: Float = 0
            for i in 0..<(frame.count - lag) {
                corr += frame[i] * frame[i + lag]
            }
            corr /= Float(frame.count - lag)

            if corr > maxCorr {
                maxCorr = corr
                bestLag = lag
            }
        }

        guard bestLag > 0 else { return nil }
        return config.sampleRate / Float(bestLag)
    }

    private func calculateSimplifiedMFCC(_ samples: [Float]) -> [Float] {
        // Simplified spectral features (not true MFCC but representative)
        guard samples.count >= config.frameSize else {
            return [Float](repeating: 0, count: config.mfccCoefficients)
        }

        // Use center frame for feature extraction
        let centerStart = (samples.count - config.frameSize) / 2
        let frame = Array(samples[centerStart..<centerStart + config.frameSize])

        // Apply Hanning window
        let windowed = applyHanningWindow(frame)

        // Calculate power spectrum magnitude
        let spectrum = calculateMagnitudeSpectrum(windowed)

        // Divide spectrum into mel-scale bands and average
        var features = [Float](repeating: 0, count: config.mfccCoefficients)
        let bandSize = spectrum.count / config.mfccCoefficients

        for i in 0..<config.mfccCoefficients {
            let start = i * bandSize
            let end = min(start + bandSize, spectrum.count)
            let bandSum = spectrum[start..<end].reduce(0, +)
            features[i] = log(max(bandSum / Float(end - start), 1e-10))
        }

        return features
    }

    private func applyHanningWindow(_ frame: [Float]) -> [Float] {
        var result = [Float](repeating: 0, count: frame.count)
        for i in 0..<frame.count {
            let window = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(frame.count - 1)))
            result[i] = frame[i] * window
        }
        return result
    }

    private func calculateMagnitudeSpectrum(_ samples: [Float]) -> [Float] {
        // Simple DFT for magnitude spectrum (for small frame sizes)
        let n = samples.count
        var magnitude = [Float](repeating: 0, count: n / 2)

        for k in 0..<n/2 {
            var real: Float = 0
            var imag: Float = 0

            for i in 0..<n {
                let angle = -2 * Float.pi * Float(k) * Float(i) / Float(n)
                real += samples[i] * cos(angle)
                imag += samples[i] * sin(angle)
            }

            magnitude[k] = sqrt(real * real + imag * imag)
        }

        return magnitude
    }

    private func createProfile(speakerID: SpeakerID, features: AudioFeatures) -> SpeakerProfile {
        SpeakerProfile(
            speakerID: speakerID,
            mfccFeatures: features.mfcc,
            pitchMean: features.pitchMean,
            pitchVariance: features.pitchVariance,
            energyMean: features.energyMean,
            energyVariance: features.energyVariance,
            sampleCount: 1
        )
    }

    private func updateProfile(_ profile: SpeakerProfile, with features: AudioFeatures) -> SpeakerProfile {
        // Exponential moving average for profile update
        let alpha: Float = 0.3
        let newCount = profile.sampleCount + 1

        // Update MFCC with weighted average
        var updatedMFCC = profile.mfccFeatures
        for i in 0..<min(updatedMFCC.count, features.mfcc.count) {
            updatedMFCC[i] = (1 - alpha) * profile.mfccFeatures[i] + alpha * features.mfcc[i]
        }

        return SpeakerProfile(
            speakerID: profile.speakerID,
            mfccFeatures: updatedMFCC,
            pitchMean: (1 - alpha) * profile.pitchMean + alpha * features.pitchMean,
            pitchVariance: (1 - alpha) * profile.pitchVariance + alpha * features.pitchVariance,
            energyMean: (1 - alpha) * profile.energyMean + alpha * features.energyMean,
            energyVariance: (1 - alpha) * profile.energyVariance + alpha * features.energyVariance,
            sampleCount: newCount
        )
    }

    private func calculateSimilarity(features: AudioFeatures, profile: SpeakerProfile) -> Float {
        // Weighted combination of feature similarities
        let mfccSimilarity = calculateMFCCSimilarity(features.mfcc, profile.mfccFeatures)
        let pitchSimilarity = calculateGaussianSimilarity(
            value: features.pitchMean,
            mean: profile.pitchMean,
            variance: max(profile.pitchVariance, 10)
        )
        let energySimilarity = calculateGaussianSimilarity(
            value: features.energyMean,
            mean: profile.energyMean,
            variance: max(profile.energyVariance, 0.001)
        )

        // Weighted combination
        let weights: (mfcc: Float, pitch: Float, energy: Float) = (0.6, 0.3, 0.1)

        return weights.mfcc * mfccSimilarity +
               weights.pitch * pitchSimilarity +
               weights.energy * energySimilarity
    }

    private func calculateMFCCSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard !a.isEmpty && !b.isEmpty else { return 0 }

        let minLength = min(a.count, b.count)
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<minLength {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        // Cosine similarity normalized to [0, 1]
        return (dotProduct / denominator + 1) / 2
    }

    private func calculateGaussianSimilarity(value: Float, mean: Float, variance: Float) -> Float {
        let diff = value - mean
        return exp(-(diff * diff) / (2 * variance))
    }
}

// MARK: - Audio Features

private struct AudioFeatures {
    let mfcc: [Float]
    let pitchMean: Float
    let pitchVariance: Float
    let energyMean: Float
    let energyVariance: Float
}
