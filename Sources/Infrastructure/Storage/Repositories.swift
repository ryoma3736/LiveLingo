import Foundation

// MARK: - Settings Repository

/// UserDefaults-based settings repository
public actor UserDefaultsSettingsRepository: SettingsRepositoryProtocol {
    private let defaults: UserDefaults
    private let settingsKey = "com.livelingo.userSettings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func getSettings() async -> UserSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings.default
        }
        return settings
    }

    public func saveSettings(_ settings: UserSettings) async throws {
        let data = try JSONEncoder().encode(settings)
        defaults.set(data, forKey: settingsKey)
    }

    public func resetToDefaults() async {
        defaults.removeObject(forKey: settingsKey)
    }
}

// MARK: - Conversation Repository

/// File-based conversation repository
public actor FileConversationRepository: ConversationRepositoryProtocol {
    private let fileManager = FileManager.default
    private var sessionsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("conversations", isDirectory: true)
    }

    public init() {
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    public func save(_ session: ConversationSession) async throws {
        let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: fileURL)
    }

    public func getAll() async throws -> [ConversationSession] {
        let files = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
        return try files.compactMap { url -> ConversationSession? in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ConversationSession.self, from: data)
        }.sorted { $0.startTime > $1.startTime }
    }

    public func get(id: UUID) async throws -> ConversationSession? {
        let fileURL = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ConversationSession.self, from: data)
    }

    public func delete(id: UUID) async throws {
        let fileURL = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
    }

    public func search(query: String) async throws -> [ConversationSession] {
        let all = try await getAll()
        let lowercasedQuery = query.lowercased()
        return all.filter { session in
            session.transcript.contains { item in
                item.originalText.lowercased().contains(lowercasedQuery) ||
                item.translatedText.lowercased().contains(lowercasedQuery)
            }
        }
    }

    public func getRecent(limit: Int) async throws -> [ConversationSession] {
        let all = try await getAll()
        return Array(all.prefix(limit))
    }

    public func export(_ session: ConversationSession, format: ExportFormat) async throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(session)
        case .plainText:
            let text = session.transcript.map { "\($0.originalText)\n→ \($0.translatedText)" }.joined(separator: "\n\n")
            return text.data(using: .utf8) ?? Data()
        case .markdown:
            let md = "# Conversation \(session.startTime)\n\n" +
                session.transcript.map { "**\($0.originalText)**\n\n> \($0.translatedText)" }.joined(separator: "\n\n---\n\n")
            return md.data(using: .utf8) ?? Data()
        case .pdf:
            // PDF export would require more complex implementation
            return try JSONEncoder().encode(session)
        }
    }
}

// MARK: - Glossary Repository

/// File-based glossary repository
public actor FileGlossaryRepository: GlossaryRepositoryProtocol {
    private let fileManager = FileManager.default
    private var glossariesDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("glossaries", isDirectory: true)
    }

    public init() {
        try? fileManager.createDirectory(at: glossariesDirectory, withIntermediateDirectories: true)
    }

    public func save(_ glossary: Glossary) async throws {
        let fileURL = glossariesDirectory.appendingPathComponent("\(glossary.id.uuidString).json")
        let data = try JSONEncoder().encode(glossary)
        try data.write(to: fileURL)
    }

    public func getAll() async throws -> [Glossary] {
        let files = try fileManager.contentsOfDirectory(at: glossariesDirectory, includingPropertiesForKeys: nil)
        return try files.compactMap { url -> Glossary? in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Glossary.self, from: data)
        }
    }

    public func get(id: UUID) async throws -> Glossary? {
        let fileURL = glossariesDirectory.appendingPathComponent("\(id.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Glossary.self, from: data)
    }

    public func delete(id: UUID) async throws {
        let fileURL = glossariesDirectory.appendingPathComponent("\(id.uuidString).json")
        try fileManager.removeItem(at: fileURL)
    }

    public func getActive(for sourceLanguage: SupportedLanguage, to targetLanguage: SupportedLanguage) async throws -> [Glossary] {
        let all = try await getAll()
        return all.filter { glossary in
            glossary.isActive &&
            glossary.sourceLanguage == sourceLanguage &&
            glossary.targetLanguage == targetLanguage
        }
    }

    public func importGlossary(from data: Data, format: GlossaryFormat) async throws -> Glossary {
        switch format {
        case .json:
            return try JSONDecoder().decode(Glossary.self, from: data)
        case .csv:
            // Simple CSV parsing
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw LiveLingoError.storageFailed(underlying: NSError(domain: "GlossaryRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid CSV data"]))
            }
            let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var entries: [GlossaryEntry] = []
            for line in lines.dropFirst() { // Skip header
                let columns = line.components(separatedBy: ",")
                if columns.count >= 2 {
                    entries.append(GlossaryEntry(
                        sourceTerm: columns[0].trimmingCharacters(in: .whitespaces),
                        targetTerm: columns[1].trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
            return Glossary(
                name: "Imported Glossary",
                sourceLanguage: .japanese,
                targetLanguage: .englishUS,
                entries: entries
            )
        case .tbx:
            // TBX import would require XML parsing
            throw LiveLingoError.storageFailed(underlying: NSError(domain: "GlossaryRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "TBX import not yet implemented"]))
        }
    }

    public func exportGlossary(_ glossary: Glossary, format: GlossaryFormat) async throws -> Data {
        switch format {
        case .json:
            return try JSONEncoder().encode(glossary)
        case .csv:
            var csv = "source,target,notes\n"
            for entry in glossary.entries {
                csv += "\(entry.sourceTerm),\(entry.targetTerm),\(entry.notes ?? "")\n"
            }
            return csv.data(using: .utf8) ?? Data()
        case .tbx:
            throw LiveLingoError.storageFailed(underlying: NSError(domain: "GlossaryRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "TBX export not yet implemented"]))
        }
    }
}
