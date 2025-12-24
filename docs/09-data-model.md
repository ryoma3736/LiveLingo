# LiveLingo - データモデル・永続化機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | データモデル・永続化機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #10 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

アプリケーションで使用するデータの構造定義と永続化戦略を規定する。

### 2.2 主要責務

1. ドメインモデルの定義
2. データ永続化（SwiftData）
3. キャッシュ管理
4. データ同期（iCloud）
5. マイグレーション戦略

---

## 3. データモデル

### 3.1 ドメインモデル一覧

| モデル名 | 説明 | 永続化 |
|---------|------|--------|
| Conversation | 会話セッション | Yes |
| TranscriptItem | 通訳ログエントリ | Yes |
| UserSettings | ユーザー設定 | Yes |
| LanguagePair | 言語ペア設定 | Yes |
| Glossary | 専門用語辞書 | Yes |
| VoicePreference | 音声設定 | Yes |

### 3.2 SwiftDataモデル定義

```swift
import SwiftData
import Foundation

// MARK: - Conversation (会話セッション)

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String?
    var sourceLanguageCode: String
    var targetLanguageCode: String
    var createdAt: Date
    var updatedAt: Date
    var duration: TimeInterval
    var isFavorite: Bool

    @Relationship(deleteRule: .cascade, inverse: \TranscriptItem.conversation)
    var transcripts: [TranscriptItem]

    init(
        sourceLanguageCode: String,
        targetLanguageCode: String
    ) {
        self.id = UUID()
        self.sourceLanguageCode = sourceLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.createdAt = Date()
        self.updatedAt = Date()
        self.duration = 0
        self.isFavorite = false
        self.transcripts = []
    }

    // 自動タイトル生成
    func generateTitle() {
        if let firstTranscript = transcripts.first {
            let maxLength = 30
            let text = firstTranscript.originalText
            title = text.count > maxLength
                ? String(text.prefix(maxLength)) + "..."
                : text
        }
    }
}

// MARK: - TranscriptItem (通訳ログ)

@Model
final class TranscriptItem {
    @Attribute(.unique) var id: UUID
    var speakerID: Int  // 0: Speaker1, 1: Speaker2
    var originalText: String
    var translatedText: String
    var timestamp: Date
    var duration: TimeInterval
    var confidence: Float

    var conversation: Conversation?

    init(
        speakerID: Int,
        originalText: String,
        translatedText: String,
        confidence: Float = 1.0
    ) {
        self.id = UUID()
        self.speakerID = speakerID
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = Date()
        self.duration = 0
        self.confidence = confidence
    }
}

// MARK: - UserSettings (ユーザー設定)

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID

    // 言語設定
    var sourceLanguageCode: String
    var targetLanguageCode: String
    var appLanguageCode: String  // UI言語（日/英/中）

    // 音声設定
    var preferredVoiceID: String?
    var speechRate: Float
    var speechPitch: Float
    var volume: Float

    // 認識設定
    var useOnDeviceRecognition: Bool
    var autoDetectLanguage: Bool

    // 表示設定
    var showOriginalText: Bool
    var fontSize: Float
    var isDarkMode: Bool?  // nil = システム設定に従う

    // 省電力設定
    var powerSavingMode: Bool
    var autoStopAfterMinutes: Int?

    init() {
        self.id = UUID()
        self.sourceLanguageCode = "ja-JP"
        self.targetLanguageCode = "en-US"
        self.appLanguageCode = "ja"
        self.speechRate = 1.0
        self.speechPitch = 1.0
        self.volume = 1.0
        self.useOnDeviceRecognition = false
        self.autoDetectLanguage = false
        self.showOriginalText = true
        self.fontSize = 1.0
        self.powerSavingMode = false
    }
}

// MARK: - Glossary (専門用語辞書)

@Model
final class Glossary {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceLanguageCode: String
    var targetLanguageCode: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \GlossaryEntry.glossary)
    var entries: [GlossaryEntry]

    init(
        name: String,
        sourceLanguageCode: String,
        targetLanguageCode: String
    ) {
        self.id = UUID()
        self.name = name
        self.sourceLanguageCode = sourceLanguageCode
        self.targetLanguageCode = targetLanguageCode
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isActive = true
        self.entries = []
    }
}

// MARK: - GlossaryEntry (辞書エントリ)

@Model
final class GlossaryEntry {
    @Attribute(.unique) var id: UUID
    var sourceText: String
    var targetText: String
    var caseSensitive: Bool
    var context: String?

    var glossary: Glossary?

    init(
        sourceText: String,
        targetText: String,
        caseSensitive: Bool = false,
        context: String? = nil
    ) {
        self.id = UUID()
        self.sourceText = sourceText
        self.targetText = targetText
        self.caseSensitive = caseSensitive
        self.context = context
    }
}

// MARK: - VoicePreference (音声設定)

@Model
final class VoicePreference {
    @Attribute(.unique) var id: UUID
    var languageCode: String
    var voiceID: String
    var voiceType: String  // "system", "coefont", "personal"
    var displayName: String

    init(
        languageCode: String,
        voiceID: String,
        voiceType: String,
        displayName: String
    ) {
        self.id = UUID()
        self.languageCode = languageCode
        self.voiceID = voiceID
        self.voiceType = voiceType
        self.displayName = displayName
    }
}
```

---

## 4. リポジトリパターン

### 4.1 Repository Protocol

```swift
// MARK: - Base Repository Protocol

protocol RepositoryProtocol {
    associatedtype Entity

    func getAll() async throws -> [Entity]
    func get(by id: UUID) async throws -> Entity?
    func save(_ entity: Entity) async throws
    func delete(_ entity: Entity) async throws
}

// MARK: - Conversation Repository

protocol ConversationRepositoryProtocol: RepositoryProtocol where Entity == Conversation {
    func getRecent(limit: Int) async throws -> [Conversation]
    func getFavorites() async throws -> [Conversation]
    func search(query: String) async throws -> [Conversation]
    func getByDateRange(from: Date, to: Date) async throws -> [Conversation]
}

// MARK: - Implementation

final class ConversationRepository: ConversationRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getAll() async throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func get(by id: UUID) async throws -> Conversation? {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func getRecent(limit: Int) async throws -> [Conversation] {
        var descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func getFavorites() async throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func search(query: String) async throws -> [Conversation] {
        // 全文検索
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate { conversation in
                conversation.transcripts.contains { transcript in
                    transcript.originalText.localizedStandardContains(query) ||
                    transcript.translatedText.localizedStandardContains(query)
                }
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func getByDateRange(from: Date, to: Date) async throws -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            predicate: #Predicate {
                $0.createdAt >= from && $0.createdAt <= to
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ entity: Conversation) async throws {
        entity.updatedAt = Date()
        modelContext.insert(entity)
        try modelContext.save()
    }

    func delete(_ entity: Conversation) async throws {
        modelContext.delete(entity)
        try modelContext.save()
    }
}
```

---

## 5. キャッシュ管理

### 5.1 翻訳キャッシュ

```swift
// MARK: - Translation Cache

final class TranslationCache {
    static let shared = TranslationCache()

    private var cache: [String: CacheEntry] = [:]
    private let lock = NSLock()
    private let maxEntries = 1000
    private let maxAge: TimeInterval = 3600  // 1時間

    struct CacheEntry {
        let translation: String
        let timestamp: Date
        let hitCount: Int
    }

    // MARK: - キャッシュ操作

    func get(
        text: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> String? {
        let key = cacheKey(text: text, source: sourceLanguage, target: targetLanguage)

        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[key] else { return nil }

        // 有効期限チェック
        if Date().timeIntervalSince(entry.timestamp) > maxAge {
            cache.removeValue(forKey: key)
            return nil
        }

        // ヒットカウント更新
        cache[key] = CacheEntry(
            translation: entry.translation,
            timestamp: entry.timestamp,
            hitCount: entry.hitCount + 1
        )

        return entry.translation
    }

    func set(
        text: String,
        translation: String,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        let key = cacheKey(text: text, source: sourceLanguage, target: targetLanguage)

        lock.lock()
        defer { lock.unlock() }

        // 容量制限チェック
        if cache.count >= maxEntries {
            evictOldEntries()
        }

        cache[key] = CacheEntry(
            translation: translation,
            timestamp: Date(),
            hitCount: 1
        )
    }

    // MARK: - キャッシュ管理

    func trimOldEntries(keepPercent: Double) {
        lock.lock()
        defer { lock.unlock() }

        let sortedKeys = cache.keys.sorted { key1, key2 in
            let entry1 = cache[key1]!
            let entry2 = cache[key2]!
            return entry1.timestamp > entry2.timestamp
        }

        let keepCount = Int(Double(sortedKeys.count) * keepPercent)
        let keysToRemove = sortedKeys.dropFirst(keepCount)

        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    // MARK: - Private

    private func cacheKey(text: String, source: String, target: String) -> String {
        "\(source):\(target):\(text.hashValue)"
    }

    private func evictOldEntries() {
        // LRU方式で古いエントリを削除
        let sortedEntries = cache.sorted { $0.value.hitCount < $1.value.hitCount }
        let removeCount = cache.count / 4  // 25%削除

        for (key, _) in sortedEntries.prefix(removeCount) {
            cache.removeValue(forKey: key)
        }
    }
}
```

---

## 6. iCloud同期

### 6.1 CloudKit設定

```swift
// MARK: - CloudKit Configuration

extension ModelConfiguration {
    static var cloudKitEnabled: ModelConfiguration {
        ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
    }

    static var localOnly: ModelConfiguration {
        ModelConfiguration(
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: nil
        )
    }
}

// MARK: - Sync Manager

final class CloudSyncManager: ObservableObject {
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?

    enum SyncStatus {
        case idle
        case syncing
        case completed
        case failed(Error)
    }

    private let container: CKContainer

    init() {
        self.container = CKContainer.default()
    }

    // MARK: - 同期状態確認

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    func requestPermission() async throws -> CKContainer.ApplicationPermissionStatus {
        try await container.requestApplicationPermission(.userDiscoverability)
    }

    // MARK: - 同期操作

    func syncNow() async {
        syncStatus = .syncing

        do {
            // SwiftDataの自動同期を利用
            // 手動でトリガーが必要な場合のみ実装
            syncStatus = .completed
            lastSyncDate = Date()
        } catch {
            syncStatus = .failed(error)
        }
    }
}
```

---

## 7. データマイグレーション

### 7.1 スキーマバージョン管理

```swift
// MARK: - Schema Versions

enum SchemaVersion: Int {
    case v1 = 1
    case v2 = 2
    // 将来のバージョン
}

// MARK: - Migration Plans

enum LiveLingoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            // マイグレーションロジック
            // 例: 新しいフィールドのデフォルト値設定
        }
    )
}

// MARK: - Schema V1

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [ConversationV1.self, TranscriptItemV1.self]
    }

    @Model
    final class ConversationV1 {
        var id: UUID
        var sourceLanguageCode: String
        var targetLanguageCode: String
        var createdAt: Date
        // V1のスキーマ
    }

    @Model
    final class TranscriptItemV1 {
        var id: UUID
        var originalText: String
        var translatedText: String
        // V1のスキーマ
    }
}

// MARK: - Schema V2

enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Conversation.self, TranscriptItem.self, UserSettings.self, Glossary.self]
    }
}
```

---

## 8. データエクスポート/インポート

### 8.1 エクスポート機能

```swift
// MARK: - Export Manager

final class DataExportManager {
    enum ExportFormat {
        case json
        case csv
        case txt
    }

    func exportConversation(
        _ conversation: Conversation,
        format: ExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            return try exportAsJSON(conversation)
        case .csv:
            return try exportAsCSV(conversation)
        case .txt:
            return try exportAsTXT(conversation)
        }
    }

    private func exportAsJSON(_ conversation: Conversation) throws -> Data {
        let exportData = ConversationExportData(
            id: conversation.id.uuidString,
            sourceLanguage: conversation.sourceLanguageCode,
            targetLanguage: conversation.targetLanguageCode,
            createdAt: conversation.createdAt,
            transcripts: conversation.transcripts.map { transcript in
                TranscriptExportData(
                    speaker: transcript.speakerID,
                    original: transcript.originalText,
                    translated: transcript.translatedText,
                    timestamp: transcript.timestamp
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(exportData)
    }

    private func exportAsCSV(_ conversation: Conversation) throws -> Data {
        var csv = "Speaker,Original,Translated,Timestamp\n"

        for transcript in conversation.transcripts {
            let speaker = transcript.speakerID == 0 ? "Speaker1" : "Speaker2"
            let original = escapeCSV(transcript.originalText)
            let translated = escapeCSV(transcript.translatedText)
            let timestamp = ISO8601DateFormatter().string(from: transcript.timestamp)

            csv += "\(speaker),\(original),\(translated),\(timestamp)\n"
        }

        return csv.data(using: .utf8)!
    }

    private func exportAsTXT(_ conversation: Conversation) throws -> Data {
        var text = "会話記録\n"
        text += "言語: \(conversation.sourceLanguageCode) → \(conversation.targetLanguageCode)\n"
        text += "日時: \(conversation.createdAt)\n"
        text += "---\n\n"

        for transcript in conversation.transcripts {
            let speaker = transcript.speakerID == 0 ? "[Speaker 1]" : "[Speaker 2]"
            text += "\(speaker)\n"
            text += "原文: \(transcript.originalText)\n"
            text += "訳文: \(transcript.translatedText)\n\n"
        }

        return text.data(using: .utf8)!
    }

    private func escapeCSV(_ text: String) -> String {
        var escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
}

// MARK: - Export Data Structures

struct ConversationExportData: Codable {
    let id: String
    let sourceLanguage: String
    let targetLanguage: String
    let createdAt: Date
    let transcripts: [TranscriptExportData]
}

struct TranscriptExportData: Codable {
    let speaker: Int
    let original: String
    let translated: String
    let timestamp: Date
}
```

---

## 9. データ統計

### 9.1 使用統計

```swift
// MARK: - Usage Statistics

final class UsageStatisticsManager {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getStatistics() async throws -> UsageStatistics {
        let conversations = try modelContext.fetch(FetchDescriptor<Conversation>())

        let totalConversations = conversations.count
        let totalTranscripts = conversations.reduce(0) { $0 + $1.transcripts.count }
        let totalDuration = conversations.reduce(0.0) { $0 + $1.duration }

        // 言語ペア統計
        var languagePairCounts: [String: Int] = [:]
        for conversation in conversations {
            let pair = "\(conversation.sourceLanguageCode)-\(conversation.targetLanguageCode)"
            languagePairCounts[pair, default: 0] += 1
        }

        // 日別統計
        let calendar = Calendar.current
        var dailyCounts: [Date: Int] = [:]
        for conversation in conversations {
            let day = calendar.startOfDay(for: conversation.createdAt)
            dailyCounts[day, default: 0] += 1
        }

        return UsageStatistics(
            totalConversations: totalConversations,
            totalTranscripts: totalTranscripts,
            totalDurationMinutes: Int(totalDuration / 60),
            languagePairCounts: languagePairCounts,
            dailyCounts: dailyCounts
        )
    }
}

struct UsageStatistics {
    let totalConversations: Int
    let totalTranscripts: Int
    let totalDurationMinutes: Int
    let languagePairCounts: [String: Int]
    let dailyCounts: [Date: Int]

    var mostUsedLanguagePair: String? {
        languagePairCounts.max(by: { $0.value < $1.value })?.key
    }

    var averageConversationLength: Int {
        guard totalConversations > 0 else { return 0 }
        return totalDurationMinutes / totalConversations
    }
}
```

---

## 10. テスト仕様

### 10.1 ユニットテスト

```swift
final class ConversationRepositoryTests: XCTestCase {
    var modelContext: ModelContext!
    var sut: ConversationRepository!

    override func setUp() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Conversation.self, configurations: config)
        modelContext = ModelContext(container)
        sut = ConversationRepository(modelContext: modelContext)
    }

    func test_save_shouldPersistConversation() async throws {
        // Given
        let conversation = Conversation(
            sourceLanguageCode: "ja-JP",
            targetLanguageCode: "en-US"
        )

        // When
        try await sut.save(conversation)

        // Then
        let fetched = try await sut.get(by: conversation.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.sourceLanguageCode, "ja-JP")
    }

    func test_search_shouldFindByTranscriptText() async throws {
        // Given
        let conversation = Conversation(
            sourceLanguageCode: "ja-JP",
            targetLanguageCode: "en-US"
        )
        let transcript = TranscriptItem(
            speakerID: 0,
            originalText: "こんにちは",
            translatedText: "Hello"
        )
        conversation.transcripts.append(transcript)
        try await sut.save(conversation)

        // When
        let results = try await sut.search(query: "こんにちは")

        // Then
        XCTAssertEqual(results.count, 1)
    }
}
```

---

## 11. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
