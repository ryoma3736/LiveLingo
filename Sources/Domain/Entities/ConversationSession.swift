import Foundation

/// A complete conversation session
public struct ConversationSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public var transcripts: [TranscriptItem]
    public var duration: TimeInterval
    public var title: String?
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        transcripts: [TranscriptItem] = [],
        title: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.transcripts = transcripts
        self.duration = 0
        self.title = title
        self.isFavorite = false
    }

    /// Generated title from first transcript
    public var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        if let first = transcripts.first {
            let preview = String(first.originalText.prefix(30))
            return preview.count < first.originalText.count ? "\(preview)..." : preview
        }
        return formattedDate
    }

    /// Formatted date for display
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Total word count
    public var totalWords: Int {
        transcripts.reduce(0) { count, item in
            count + item.originalText.split(separator: " ").count + item.translatedText.split(separator: " ").count
        }
    }

    /// Add a transcript item
    public mutating func addTranscript(_ item: TranscriptItem) {
        transcripts.append(item)
        updatedAt = Date()
    }
}

/// User settings for the app
public struct UserSettings: Codable, Sendable {
    public var preferredSourceLanguage: SupportedLanguage
    public var preferredTargetLanguage: SupportedLanguage
    public var preferredVoiceID: String?
    public var autoSaveEnabled: Bool
    public var iCloudSyncEnabled: Bool
    public var hapticFeedbackEnabled: Bool
    public var darkModePreference: DarkModePreference
    public var lastUsedDate: Date?

    public init() {
        self.preferredSourceLanguage = .japanese
        self.preferredTargetLanguage = .englishUS
        self.preferredVoiceID = nil
        self.autoSaveEnabled = true
        self.iCloudSyncEnabled = true
        self.hapticFeedbackEnabled = true
        self.darkModePreference = .system
        self.lastUsedDate = nil
    }
}

/// Dark mode preference
public enum DarkModePreference: String, Codable, Sendable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}
