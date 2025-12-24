import Foundation

/// Protocol for Conversation Repository
public protocol ConversationRepositoryProtocol: Sendable {
    /// Save a conversation session
    func save(_ session: ConversationSession) async throws

    /// Get all conversation sessions
    func getAll() async throws -> [ConversationSession]

    /// Get a conversation session by ID
    func get(id: UUID) async throws -> ConversationSession?

    /// Delete a conversation session
    func delete(id: UUID) async throws

    /// Search conversations
    func search(query: String) async throws -> [ConversationSession]

    /// Get recent conversations
    func getRecent(limit: Int) async throws -> [ConversationSession]

    /// Export a session to a shareable format
    func export(_ session: ConversationSession, format: ExportFormat) async throws -> Data
}

/// Protocol for Settings Repository
public protocol SettingsRepositoryProtocol: Sendable {
    /// Get current settings
    func getSettings() async -> UserSettings

    /// Save settings
    func saveSettings(_ settings: UserSettings) async throws

    /// Reset to default settings
    func resetToDefaults() async
}

/// Protocol for Glossary Repository
public protocol GlossaryRepositoryProtocol: Sendable {
    /// Save a glossary
    func save(_ glossary: Glossary) async throws

    /// Get all glossaries
    func getAll() async throws -> [Glossary]

    /// Get a glossary by ID
    func get(id: UUID) async throws -> Glossary?

    /// Delete a glossary
    func delete(id: UUID) async throws

    /// Get active glossaries for a language pair
    func getActive(for sourceLanguage: SupportedLanguage, to targetLanguage: SupportedLanguage) async throws -> [Glossary]

    /// Import glossary from file
    func importGlossary(from data: Data, format: GlossaryFormat) async throws -> Glossary

    /// Export glossary to file
    func exportGlossary(_ glossary: Glossary, format: GlossaryFormat) async throws -> Data
}

/// Export format options
public enum ExportFormat: String, Sendable {
    case plainText = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case json = "json"
}

/// Glossary import/export format
public enum GlossaryFormat: String, Sendable {
    case csv = "csv"
    case json = "json"
    case tbx = "tbx" // TermBase eXchange
}
