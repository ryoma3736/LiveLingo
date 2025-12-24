import Foundation

/// A custom glossary for specialized terminology
public struct Glossary: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var sourceLanguage: SupportedLanguage
    public var targetLanguage: SupportedLanguage
    public var entries: [GlossaryEntry]
    public let createdAt: Date
    public var updatedAt: Date
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        entries: [GlossaryEntry] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.entries = entries
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
    }

    /// Add a new entry
    public mutating func addEntry(_ entry: GlossaryEntry) {
        entries.append(entry)
        updatedAt = Date()
    }

    /// Remove an entry
    public mutating func removeEntry(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        updatedAt = Date()
    }

    /// Find translation for a term
    public func findTranslation(for term: String) -> String? {
        entries.first { $0.sourceTerm.lowercased() == term.lowercased() }?.targetTerm
    }
}

/// A single entry in a glossary
public struct GlossaryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public var sourceTerm: String
    public var targetTerm: String
    public var notes: String?
    public var caseSensitive: Bool

    public init(
        id: UUID = UUID(),
        sourceTerm: String,
        targetTerm: String,
        notes: String? = nil,
        caseSensitive: Bool = false
    ) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.targetTerm = targetTerm
        self.notes = notes
        self.caseSensitive = caseSensitive
    }
}

/// Voice option for TTS
public struct VoiceOption: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let language: SupportedLanguage
    public let provider: VoiceProvider
    public let gender: VoiceGender
    public let isDefault: Bool

    public init(
        id: String,
        name: String,
        language: SupportedLanguage,
        provider: VoiceProvider,
        gender: VoiceGender = .neutral,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.provider = provider
        self.gender = gender
        self.isDefault = isDefault
    }
}

/// Voice provider types
public enum VoiceProvider: String, Codable, Sendable {
    case system = "system"      // AVSpeechSynthesizer
    case coeFont = "coefont"    // CoeFont API
    case personal = "personal"  // Personal Voice (iOS 17+)
}

/// Voice gender
public enum VoiceGender: String, Codable, Sendable {
    case male = "male"
    case female = "female"
    case neutral = "neutral"
}
