import Foundation
import Dependencies

// MARK: - Dependency Keys

/// STT Service Dependency
public struct STTServiceKey: DependencyKey {
    public static var liveValue: any STTServiceProtocol {
        AppleSTTService()
    }

    public static var testValue: any STTServiceProtocol {
        MockSTTService()
    }

    public static var previewValue: any STTServiceProtocol {
        MockSTTService()
    }
}

/// Translation Service Dependency
public struct TranslationServiceKey: DependencyKey {
    public static var liveValue: any TranslationServiceProtocol {
        // AppleTranslationService now uses Gemini API internally for iOS 16 compatibility
        AppleTranslationService()
    }

    public static var testValue: any TranslationServiceProtocol {
        MockTranslationService()
    }

    public static var previewValue: any TranslationServiceProtocol {
        MockTranslationService()
    }
}

/// TTS Service Dependency
public struct TTSServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any TTSServiceProtocol {
        AppleTTSService()
    }

    public static var testValue: any TTSServiceProtocol {
        MockTTSService()
    }

    public static var previewValue: any TTSServiceProtocol {
        MockTTSService()
    }
}

/// Conversation Repository Dependency
public struct ConversationRepositoryKey: DependencyKey {
    public static var liveValue: any ConversationRepositoryProtocol {
        FileConversationRepository()
    }

    public static var testValue: any ConversationRepositoryProtocol {
        MockConversationRepository()
    }

    public static var previewValue: any ConversationRepositoryProtocol {
        MockConversationRepository()
    }
}

/// Settings Repository Dependency
public struct SettingsRepositoryKey: DependencyKey {
    public static var liveValue: any SettingsRepositoryProtocol {
        UserDefaultsSettingsRepository()
    }

    public static var testValue: any SettingsRepositoryProtocol {
        MockSettingsRepository()
    }

    public static var previewValue: any SettingsRepositoryProtocol {
        MockSettingsRepository()
    }
}

/// Glossary Repository Dependency
public struct GlossaryRepositoryKey: DependencyKey {
    public static var liveValue: any GlossaryRepositoryProtocol {
        FileGlossaryRepository()
    }

    public static var testValue: any GlossaryRepositoryProtocol {
        MockGlossaryRepository()
    }

    public static var previewValue: any GlossaryRepositoryProtocol {
        MockGlossaryRepository()
    }
}

/// Gemini Live Service Dependency
public struct GeminiLiveServiceKey: DependencyKey {
    public static var liveValue: GeminiLiveService {
        GeminiLiveService()
    }

    public static var testValue: GeminiLiveService {
        GeminiLiveService()
    }

    public static var previewValue: GeminiLiveService {
        GeminiLiveService()
    }
}

/// Live Translation Service Dependency
public struct LiveTranslationServiceKey: DependencyKey {
    public static var liveValue: LiveTranslationService {
        LiveTranslationService()
    }

    public static var testValue: LiveTranslationService {
        LiveTranslationService()
    }

    public static var previewValue: LiveTranslationService {
        LiveTranslationService()
    }
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    /// STT Service
    public var sttService: any STTServiceProtocol {
        get { self[STTServiceKey.self] }
        set { self[STTServiceKey.self] = newValue }
    }

    /// Translation Service
    public var translationService: any TranslationServiceProtocol {
        get { self[TranslationServiceKey.self] }
        set { self[TranslationServiceKey.self] = newValue }
    }

    /// TTS Service
    public var ttsService: any TTSServiceProtocol {
        get { self[TTSServiceKey.self] }
        set { self[TTSServiceKey.self] = newValue }
    }

    /// Conversation Repository
    public var conversationRepository: any ConversationRepositoryProtocol {
        get { self[ConversationRepositoryKey.self] }
        set { self[ConversationRepositoryKey.self] = newValue }
    }

    /// Settings Repository
    public var settingsRepository: any SettingsRepositoryProtocol {
        get { self[SettingsRepositoryKey.self] }
        set { self[SettingsRepositoryKey.self] = newValue }
    }

    /// Glossary Repository
    public var glossaryRepository: any GlossaryRepositoryProtocol {
        get { self[GlossaryRepositoryKey.self] }
        set { self[GlossaryRepositoryKey.self] = newValue }
    }

    /// Gemini Live Service
    public var geminiLiveService: GeminiLiveService {
        get { self[GeminiLiveServiceKey.self] }
        set { self[GeminiLiveServiceKey.self] = newValue }
    }

    /// Live Translation Service (Gemini-powered)
    public var liveTranslationService: LiveTranslationService {
        get { self[LiveTranslationServiceKey.self] }
        set { self[LiveTranslationServiceKey.self] = newValue }
    }
}

// MARK: - App Environment

/// Application environment configuration
public enum AppEnvironment: String, Sendable {
    case development
    case staging
    case production

    public static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    public var baseURL: String {
        switch self {
        case .development:
            return "https://dev-api.livelingo.app"
        case .staging:
            return "https://staging-api.livelingo.app"
        case .production:
            return "https://api.livelingo.app"
        }
    }
}

// MARK: - Repository Implementations

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
            return UserSettings()
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

/// File-based conversation repository
public actor FileConversationRepository: ConversationRepositoryProtocol {
    private let fileManager = FileManager.default
    private var sessionsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("conversations", isDirectory: true)
    }

    public init() {}

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    public func save(_ session: ConversationSession) async throws {
        ensureDirectoryExists()
        let fileURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).json")
        let data = try JSONEncoder().encode(session)
        try data.write(to: fileURL)
    }

    public func getAll() async throws -> [ConversationSession] {
        guard fileManager.fileExists(atPath: sessionsDirectory.path) else { return [] }
        let files = try fileManager.contentsOfDirectory(at: sessionsDirectory, includingPropertiesForKeys: nil)
        return try files.compactMap { url -> ConversationSession? in
            guard url.pathExtension == "json" else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ConversationSession.self, from: data)
        }.sorted(by: { $0.createdAt > $1.createdAt })
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
            session.transcripts.contains { item in
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
            let text = session.transcripts.map { "\($0.originalText)\n→ \($0.translatedText)" }.joined(separator: "\n\n")
            return text.data(using: String.Encoding.utf8) ?? Data()
        case .markdown:
            let md = "# Conversation\n\n" +
                session.transcripts.map { "**\($0.originalText)**\n\n> \($0.translatedText)" }.joined(separator: "\n\n---\n\n")
            return md.data(using: String.Encoding.utf8) ?? Data()
        case .pdf:
            return try JSONEncoder().encode(session)
        }
    }
}

/// File-based glossary repository
public actor FileGlossaryRepository: GlossaryRepositoryProtocol {
    private let fileManager = FileManager.default
    private var glossariesDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("glossaries", isDirectory: true)
    }

    public init() {}

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: glossariesDirectory, withIntermediateDirectories: true)
    }

    public func save(_ glossary: Glossary) async throws {
        ensureDirectoryExists()
        let fileURL = glossariesDirectory.appendingPathComponent("\(glossary.id.uuidString).json")
        let data = try JSONEncoder().encode(glossary)
        try data.write(to: fileURL)
    }

    public func getAll() async throws -> [Glossary] {
        guard fileManager.fileExists(atPath: glossariesDirectory.path) else { return [] }
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
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw LiveLingoError.storageFailed(underlying: NSError(domain: "GlossaryRepository", code: -1, userInfo: nil))
            }
            let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var entries: [GlossaryEntry] = []
            for line in lines.dropFirst() {
                let columns = line.components(separatedBy: ",")
                if columns.count >= 2 {
                    entries.append(GlossaryEntry(
                        sourceTerm: columns[0].trimmingCharacters(in: .whitespaces),
                        targetTerm: columns[1].trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
            return Glossary(
                name: "Imported",
                sourceLanguage: .japanese,
                targetLanguage: .englishUS,
                entries: entries
            )
        case .tbx:
            throw LiveLingoError.storageFailed(underlying: NSError(domain: "GlossaryRepository", code: -1, userInfo: nil))
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
            throw LiveLingoError.storageFailed(underlying: NSError(domain: "GlossaryRepository", code: -1, userInfo: nil))
        }
    }
}
