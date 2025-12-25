import Foundation
import SwiftData

// MARK: - Glossary Manager

/// Manages glossaries for specialized terminology in translation
public actor GlossaryManager: GlossaryManagerProtocol {
    // MARK: - Properties

    private var loadedGlossaries: [UUID: Glossary] = [:]
    private var activeGlossaryIDs: Set<UUID> = []
    private var termIndex: [String: [(glossaryID: UUID, entry: GlossaryEntry)]] = [:]

    public nonisolated var activeGlossaries: [Glossary] {
        // Note: In production, this would be synchronized properly
        []
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - GlossaryManagerProtocol

    public nonisolated func applyGlossary(_ text: String, glossary: Glossary) -> String {
        var result = text

        for entry in glossary.entries {
            let searchTerm = entry.caseSensitive ? entry.sourceTerm : entry.sourceTerm.lowercased()
            let textToSearch = entry.caseSensitive ? result : result.lowercased()

            if textToSearch.contains(searchTerm) {
                // Replace term with translation
                if entry.caseSensitive {
                    result = result.replacingOccurrences(of: entry.sourceTerm, with: entry.targetTerm)
                } else {
                    result = result.replacingOccurrences(
                        of: entry.sourceTerm,
                        with: entry.targetTerm,
                        options: .caseInsensitive
                    )
                }
            }
        }

        return result
    }

    public nonisolated func verifyTerms(in translation: String, glossary: Glossary) -> Bool {
        // Verify all required terms are present in translation
        for entry in glossary.entries {
            let termToFind = entry.caseSensitive ? entry.targetTerm : entry.targetTerm.lowercased()
            let translationToSearch = entry.caseSensitive ? translation : translation.lowercased()

            if !translationToSearch.contains(termToFind) {
                return false
            }
        }
        return true
    }

    // MARK: - Extended Glossary Management

    /// Load a glossary into memory
    public func loadGlossary(_ glossary: Glossary) {
        loadedGlossaries[glossary.id] = glossary
        indexGlossaryTerms(glossary)
    }

    /// Unload a glossary from memory
    public func unloadGlossary(_ glossaryID: UUID) {
        loadedGlossaries.removeValue(forKey: glossaryID)
        activeGlossaryIDs.remove(glossaryID)
        rebuildTermIndex()
    }

    /// Activate a glossary for translation
    public func activateGlossary(_ glossaryID: UUID) {
        guard loadedGlossaries[glossaryID] != nil else { return }
        activeGlossaryIDs.insert(glossaryID)
    }

    /// Deactivate a glossary
    public func deactivateGlossary(_ glossaryID: UUID) {
        activeGlossaryIDs.remove(glossaryID)
    }

    /// Get all active glossaries
    public func getActiveGlossaries() -> [Glossary] {
        activeGlossaryIDs.compactMap { loadedGlossaries[$0] }
    }

    /// Apply all active glossaries to text (pre-translation)
    public func applyActiveGlossaries(to text: String) -> GlossaryApplicationResult {
        var result = text
        var appliedTerms: [AppliedTerm] = []

        for glossaryID in activeGlossaryIDs {
            guard let glossary = loadedGlossaries[glossaryID] else { continue }

            for entry in glossary.entries {
                let (newText, wasApplied) = applyEntry(entry, to: result)
                if wasApplied {
                    appliedTerms.append(AppliedTerm(
                        sourceTerm: entry.sourceTerm,
                        targetTerm: entry.targetTerm,
                        glossaryID: glossaryID,
                        glossaryName: glossary.name
                    ))
                    result = newText
                }
            }
        }

        return GlossaryApplicationResult(
            originalText: text,
            processedText: result,
            appliedTerms: appliedTerms
        )
    }

    /// Verify all glossary terms are correctly translated
    public func verifyActiveGlossaries(in translation: String, sourceText: String) -> GlossaryVerificationResult {
        var missingTerms: [MissingTerm] = []
        var verifiedTerms: [AppliedTerm] = []

        for glossaryID in activeGlossaryIDs {
            guard let glossary = loadedGlossaries[glossaryID] else { continue }

            for entry in glossary.entries {
                // Check if source term was in original text
                let sourceContains = entry.caseSensitive
                    ? sourceText.contains(entry.sourceTerm)
                    : sourceText.lowercased().contains(entry.sourceTerm.lowercased())

                if sourceContains {
                    // Check if target term is in translation
                    let targetContains = entry.caseSensitive
                        ? translation.contains(entry.targetTerm)
                        : translation.lowercased().contains(entry.targetTerm.lowercased())

                    if targetContains {
                        verifiedTerms.append(AppliedTerm(
                            sourceTerm: entry.sourceTerm,
                            targetTerm: entry.targetTerm,
                            glossaryID: glossaryID,
                            glossaryName: glossary.name
                        ))
                    } else {
                        missingTerms.append(MissingTerm(
                            sourceTerm: entry.sourceTerm,
                            expectedTarget: entry.targetTerm,
                            glossaryID: glossaryID,
                            glossaryName: glossary.name
                        ))
                    }
                }
            }
        }

        return GlossaryVerificationResult(
            isValid: missingTerms.isEmpty,
            verifiedTerms: verifiedTerms,
            missingTerms: missingTerms
        )
    }

    /// Find matching terms in text
    public func findMatchingTerms(in text: String) -> [MatchedTerm] {
        var matches: [MatchedTerm] = []
        let lowercaseText = text.lowercased()

        for (term, entries) in termIndex {
            let range: Range<String.Index>?
            if text.contains(term) {
                range = text.range(of: term)
            } else if lowercaseText.contains(term.lowercased()) {
                range = lowercaseText.range(of: term.lowercased())
            } else {
                continue
            }

            if let range = range {
                for (glossaryID, entry) in entries {
                    guard let glossary = loadedGlossaries[glossaryID] else { continue }

                    matches.append(MatchedTerm(
                        term: term,
                        translation: entry.targetTerm,
                        range: range,
                        glossaryID: glossaryID,
                        glossaryName: glossary.name,
                        notes: entry.notes
                    ))
                }
            }
        }

        return matches
    }

    /// Create a prompt hint for LLM translation
    public func buildGlossaryPrompt(for text: String) -> String {
        let matches = findMatchingTerms(in: text)

        guard !matches.isEmpty else { return "" }

        var prompt = "Use the following glossary terms in your translation:\n"
        for match in matches {
            prompt += "- \"\(match.term)\" should be translated as \"\(match.translation)\""
            if let notes = match.notes {
                prompt += " (note: \(notes))"
            }
            prompt += "\n"
        }

        return prompt
    }

    // MARK: - Private Methods

    private func indexGlossaryTerms(_ glossary: Glossary) {
        for entry in glossary.entries {
            let key = entry.caseSensitive ? entry.sourceTerm : entry.sourceTerm.lowercased()
            termIndex[key, default: []].append((glossary.id, entry))
        }
    }

    private func rebuildTermIndex() {
        termIndex.removeAll()
        for glossary in loadedGlossaries.values {
            indexGlossaryTerms(glossary)
        }
    }

    private func applyEntry(_ entry: GlossaryEntry, to text: String) -> (String, Bool) {
        let searchTerm = entry.caseSensitive ? entry.sourceTerm : entry.sourceTerm.lowercased()
        let textToSearch = entry.caseSensitive ? text : text.lowercased()

        if textToSearch.contains(searchTerm) {
            let replacement = entry.caseSensitive
                ? text.replacingOccurrences(of: entry.sourceTerm, with: entry.targetTerm)
                : text.replacingOccurrences(of: entry.sourceTerm, with: entry.targetTerm, options: .caseInsensitive)
            return (replacement, true)
        }

        return (text, false)
    }
}

// MARK: - Result Types

/// Result of applying glossaries to text
public struct GlossaryApplicationResult: Sendable {
    public let originalText: String
    public let processedText: String
    public let appliedTerms: [AppliedTerm]

    public var hasChanges: Bool {
        originalText != processedText
    }
}

/// A term that was applied during translation
public struct AppliedTerm: Sendable {
    public let sourceTerm: String
    public let targetTerm: String
    public let glossaryID: UUID
    public let glossaryName: String
}

/// Result of verifying glossary terms in translation
public struct GlossaryVerificationResult: Sendable {
    public let isValid: Bool
    public let verifiedTerms: [AppliedTerm]
    public let missingTerms: [MissingTerm]
}

/// A term that was expected but not found
public struct MissingTerm: Sendable {
    public let sourceTerm: String
    public let expectedTarget: String
    public let glossaryID: UUID
    public let glossaryName: String
}

/// A term found in the source text
public struct MatchedTerm: Sendable {
    public let term: String
    public let translation: String
    public let range: Range<String.Index>
    public let glossaryID: UUID
    public let glossaryName: String
    public let notes: String?
}

// MARK: - Glossary Import/Export

/// Handles import/export of glossaries in various formats
public struct GlossaryIO: Sendable {
    /// Export glossary to CSV format
    public static func exportToCSV(_ glossary: Glossary) -> String {
        var csv = "Source Term,Target Term,Case Sensitive,Notes\n"

        for entry in glossary.entries {
            let notes = entry.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            csv += "\"\(entry.sourceTerm)\",\"\(entry.targetTerm)\",\(entry.caseSensitive),\"\(notes)\"\n"
        }

        return csv
    }

    /// Import glossary from CSV data
    public static func importFromCSV(
        _ csv: String,
        name: String,
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage
    ) -> Glossary? {
        let lines = csv.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }

        var entries: [GlossaryEntry] = []

        for line in lines.dropFirst() where !line.isEmpty {
            let columns = parseCSVLine(line)
            guard columns.count >= 2 else { continue }

            let entry = GlossaryEntry(
                sourceTerm: columns[0],
                targetTerm: columns[1],
                notes: columns.count > 3 ? columns[3] : nil,
                caseSensitive: columns.count > 2 && columns[2].lowercased() == "true"
            )
            entries.append(entry)
        }

        return Glossary(
            name: name,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            entries: entries
        )
    }

    /// Export glossary to JSON format
    public static func exportToJSON(_ glossary: Glossary) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(glossary)
    }

    /// Import glossary from JSON data
    public static func importFromJSON(_ data: Data) -> Glossary? {
        let decoder = JSONDecoder()
        return try? decoder.decode(Glossary.self, from: data)
    }

    /// Parse a single CSV line handling quoted fields
    private static func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        return result
    }
}

// MARK: - SwiftData Models

/// SwiftData model for persisting glossaries
@Model
public final class GlossaryModel {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var descriptionText: String?
    public var sourceLanguage: String
    public var targetLanguage: String
    @Relationship(deleteRule: .cascade) public var entries: [GlossaryEntryModel]
    public var createdAt: Date
    public var updatedAt: Date
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        descriptionText: String? = nil,
        sourceLanguage: String,
        targetLanguage: String,
        entries: [GlossaryEntryModel] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.descriptionText = descriptionText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }

    /// Convert to domain Glossary
    public func toGlossary() -> Glossary? {
        guard let source = SupportedLanguage(rawValue: sourceLanguage),
              let target = SupportedLanguage(rawValue: targetLanguage) else {
            return nil
        }

        return Glossary(
            id: id,
            name: name,
            description: descriptionText,
            sourceLanguage: source,
            targetLanguage: target,
            entries: entries.map { $0.toEntry() }
        )
    }
}

/// SwiftData model for glossary entries
@Model
public final class GlossaryEntryModel {
    @Attribute(.unique) public var id: UUID
    public var sourceTerm: String
    public var targetTerm: String
    public var notes: String?
    public var caseSensitive: Bool
    public var contextHint: String?

    public init(
        id: UUID = UUID(),
        sourceTerm: String,
        targetTerm: String,
        notes: String? = nil,
        caseSensitive: Bool = false,
        contextHint: String? = nil
    ) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.targetTerm = targetTerm
        self.notes = notes
        self.caseSensitive = caseSensitive
        self.contextHint = contextHint
    }

    /// Convert to domain GlossaryEntry
    public func toEntry() -> GlossaryEntry {
        GlossaryEntry(
            id: id,
            sourceTerm: sourceTerm,
            targetTerm: targetTerm,
            notes: notes,
            caseSensitive: caseSensitive
        )
    }
}
