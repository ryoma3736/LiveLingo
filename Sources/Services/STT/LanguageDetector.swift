import Foundation
import NaturalLanguage
import Speech

// MARK: - Language Detection Result

/// Result of automatic language detection
public struct LanguageDetectionResult: Sendable {
    /// Detected language
    public let language: SupportedLanguage?

    /// Confidence score (0.0 - 1.0)
    public let confidence: Float

    /// All candidate languages with scores
    public let candidates: [(language: SupportedLanguage, score: Float)]

    /// Detection method used
    public let method: DetectionMethod

    /// Timestamp
    public let timestamp: Date

    public init(
        language: SupportedLanguage?,
        confidence: Float,
        candidates: [(language: SupportedLanguage, score: Float)],
        method: DetectionMethod,
        timestamp: Date = Date()
    ) {
        self.language = language
        self.confidence = confidence
        self.candidates = candidates
        self.method = method
        self.timestamp = timestamp
    }

    public enum DetectionMethod: String, Sendable {
        case text = "NLLanguageRecognizer"
        case audio = "AudioAnalysis"
        case hybrid = "Hybrid"
    }
}

// MARK: - Language Detector Configuration

public struct LanguageDetectorConfig: Sendable {
    /// Minimum confidence to accept detection
    public let minConfidence: Float

    /// Timeout for detection (in seconds)
    public let timeout: TimeInterval

    /// Supported languages to detect
    public let supportedLanguages: [SupportedLanguage]

    /// Enable audio-based detection
    public let useAudioDetection: Bool

    public init(
        minConfidence: Float = 0.7,
        timeout: TimeInterval = 0.5,
        supportedLanguages: [SupportedLanguage] = SupportedLanguage.allCases,
        useAudioDetection: Bool = true
    ) {
        self.minConfidence = minConfidence
        self.timeout = timeout
        self.supportedLanguages = supportedLanguages
        self.useAudioDetection = useAudioDetection
    }

    public static let `default` = LanguageDetectorConfig()

    /// Phase 1 languages only (ja, en, zh-CN, ko)
    public static let phase1 = LanguageDetectorConfig(
        supportedLanguages: [.japanese, .englishUS, .chineseSimplified, .korean]
    )
}

// MARK: - Language Detector

/// Automatic language detection for speech and text
public actor LanguageDetector {
    // MARK: - Properties

    private let config: LanguageDetectorConfig
    private let textRecognizer: NLLanguageRecognizer
    private var lastDetectedLanguage: SupportedLanguage?
    private var detectionHistory: [(language: SupportedLanguage, timestamp: Date)] = []

    // MARK: - Initialization

    public init(config: LanguageDetectorConfig = .default) {
        self.config = config
        self.textRecognizer = NLLanguageRecognizer()

        // Constrain to supported languages
        let constraints = config.supportedLanguages.map { $0.nlLanguage }
        textRecognizer.languageConstraints = constraints
    }

    // MARK: - Text-based Detection

    /// Detect language from text
    /// - Parameter text: Text to analyze
    /// - Returns: Language detection result
    public func detectLanguage(from text: String) -> LanguageDetectionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return LanguageDetectionResult(
                language: nil,
                confidence: 0,
                candidates: [],
                method: .text
            )
        }

        textRecognizer.reset()
        textRecognizer.processString(text)

        // Get dominant language
        guard let dominantLanguage = textRecognizer.dominantLanguage else {
            return LanguageDetectionResult(
                language: nil,
                confidence: 0,
                candidates: [],
                method: .text
            )
        }

        // Get all hypotheses
        let hypotheses = textRecognizer.languageHypotheses(withMaximum: 5)

        // Convert to SupportedLanguage
        let candidates: [(SupportedLanguage, Float)] = hypotheses.compactMap { (nlLang, probability) in
            guard let supported = SupportedLanguage.from(nlLanguage: nlLang) else { return nil }
            return (supported, Float(probability))
        }

        let detected = SupportedLanguage.from(nlLanguage: dominantLanguage)
        let confidence = Float(hypotheses[dominantLanguage] ?? 0)

        // Update history
        if let detected = detected, confidence >= config.minConfidence {
            lastDetectedLanguage = detected
            detectionHistory.append((detected, Date()))

            // Keep only last 10 detections
            if detectionHistory.count > 10 {
                detectionHistory.removeFirst()
            }
        }

        return LanguageDetectionResult(
            language: detected,
            confidence: confidence,
            candidates: candidates,
            method: .text
        )
    }

    // MARK: - Streaming Detection

    /// Detect language from streaming text (accumulative)
    /// - Parameter text: New text chunk
    /// - Returns: Language detection result if confident enough
    public func detectLanguageStreaming(text: String) -> LanguageDetectionResult? {
        let result = detectLanguage(from: text)

        // Only return if confidence is high enough
        guard result.confidence >= config.minConfidence else {
            return nil
        }

        return result
    }

    // MARK: - Audio-based Detection

    /// Detect language from audio buffer using speech recognition hints
    /// - Parameters:
    ///   - buffer: Audio buffer
    ///   - candidateLanguages: Languages to try
    /// - Returns: Most likely language
    public func detectLanguageFromAudio(
        recognitionResults: [SupportedLanguage: String]
    ) -> LanguageDetectionResult {
        var candidates: [(SupportedLanguage, Float)] = []

        for (language, text) in recognitionResults {
            guard !text.isEmpty else { continue }

            // Get text-based confidence for this language
            let textResult = detectLanguage(from: text)

            // Score based on text length and language match
            var score: Float = 0

            if textResult.language == language {
                // Text was recognized in expected language
                score = textResult.confidence * 0.8 + Float(text.count) / 100.0 * 0.2
            } else {
                // Language mismatch penalty
                score = textResult.confidence * 0.3
            }

            candidates.append((language, min(score, 1.0)))
        }

        // Sort by score
        candidates.sort { $0.1 > $1.1 }

        let best = candidates.first

        return LanguageDetectionResult(
            language: best?.0,
            confidence: best?.1 ?? 0,
            candidates: candidates,
            method: .audio
        )
    }

    // MARK: - History-based Detection

    /// Get most frequently detected language from history
    public func getMostFrequentLanguage() -> SupportedLanguage? {
        guard !detectionHistory.isEmpty else { return lastDetectedLanguage }

        // Count occurrences
        var counts: [SupportedLanguage: Int] = [:]
        for (language, _) in detectionHistory {
            counts[language, default: 0] += 1
        }

        // Return most frequent
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Reset

    public func reset() {
        textRecognizer.reset()
        lastDetectedLanguage = nil
        detectionHistory.removeAll()
    }
}

// MARK: - SupportedLanguage Extension

extension SupportedLanguage {
    /// Convert to NLLanguage
    var nlLanguage: NLLanguage {
        switch self {
        case .japanese: return .japanese
        case .englishUS, .englishUK: return .english
        case .chineseSimplified: return .simplifiedChinese
        case .chineseTraditional: return .traditionalChinese
        case .korean: return .korean
        case .vietnamese: return .vietnamese
        case .portuguese: return .portuguese
        }
    }

    /// Create from NLLanguage
    static func from(nlLanguage: NLLanguage) -> SupportedLanguage? {
        switch nlLanguage {
        case .japanese: return .japanese
        case .english: return .englishUS
        case .simplifiedChinese: return .chineseSimplified
        case .traditionalChinese: return .chineseTraditional
        case .korean: return .korean
        case .vietnamese: return .vietnamese
        case .portuguese: return .portuguese
        default: return nil
        }
    }
}
