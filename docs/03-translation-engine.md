# LiveLingo - 翻訳エンジン機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | 翻訳エンジン機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #4 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

音声認識から得たテキストを、最小遅延で高品質に翻訳し、文脈を保持した自然な翻訳を提供する。

### 2.2 主要責務

1. リアルタイムテキスト翻訳
2. 文脈保持（会話履歴の考慮）
3. ストリーミング翻訳出力
4. 専門用語辞書の適用
5. 翻訳エンジン切替（オンデバイス/クラウド）

---

## 3. 機能要件

### 3.1 コア機能

#### F-TRN-001: リアルタイム翻訳

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TRN-001 |
| 機能名 | リアルタイム翻訳 |
| 説明 | 認識テキストを即座に翻訳 |
| 優先度 | P0（必須） |

**入力**:
```swift
struct TranslationRequest {
    let text: String                   // 翻訳対象テキスト
    let sourceLanguage: Locale         // 原言語
    let targetLanguage: Locale         // 訳言語
    let context: [ConversationTurn]?   // 会話文脈
    let glossary: [String: String]?    // 専門用語辞書
    let isPartial: Bool               // 部分結果フラグ
}
```

**出力**:
```swift
struct TranslationResult {
    let originalText: String           // 原文
    let translatedText: String         // 訳文
    let isFinal: Bool                  // 確定フラグ
    let confidence: Float              // 信頼度 (0.0-1.0)
    let timestamp: Date                // タイムスタンプ
    let processingTime: TimeInterval   // 処理時間
    let glossaryApplied: [String]      // 適用された専門用語
}
```

**受入条件**:
- [ ] 翻訳開始から500ms以内に結果を返す
- [ ] BLEU スコア40以上を達成
- [ ] 文脈を考慮した翻訳が可能

#### F-TRN-002: 文脈保持翻訳

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TRN-002 |
| 機能名 | 文脈保持翻訳 |
| 説明 | 会話履歴を考慮した翻訳 |
| 優先度 | P0（必須） |

**文脈管理**:
```swift
struct ConversationContext {
    let turns: [ConversationTurn]      // 会話履歴
    let maxTurns: Int = 10             // 最大保持数
    let speaker1Language: Locale       // 話者1の言語
    let speaker2Language: Locale       // 話者2の言語
}

struct ConversationTurn {
    let speaker: SpeakerID
    let originalText: String
    let translatedText: String
    let timestamp: Date
}
```

**受入条件**:
- [ ] 「さっきの」「あれ」などの指示語を適切に解釈
- [ ] 話者ごとの文体を維持
- [ ] 最新10ターンの文脈を考慮

#### F-TRN-003: ストリーミング翻訳

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TRN-003 |
| 機能名 | ストリーミング翻訳 |
| 説明 | 部分結果を逐次翻訳 |
| 優先度 | P0（必須） |

**Wait-k戦略**:
```swift
struct StreamingConfig {
    let waitK: Int = 3                 // k単語待ってから翻訳開始
    let flushInterval: TimeInterval = 0.5  // 強制フラッシュ間隔
    let minSegmentLength: Int = 5      // 最小セグメント長
}
```

#### F-TRN-004: 専門用語辞書

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TRN-004 |
| 機能名 | 専門用語辞書 |
| 説明 | カスタム翻訳辞書の適用 |
| 優先度 | P1 |

**辞書構造**:
```swift
struct Glossary {
    let id: UUID
    let name: String
    let entries: [GlossaryEntry]
    let sourceLanguage: Locale
    let targetLanguage: Locale
    let createdAt: Date
}

struct GlossaryEntry {
    let source: String
    let target: String
    let caseSensitive: Bool
    let context: String?  // 使用文脈の説明
}
```

---

## 4. 技術設計

### 4.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                   Translation Engine                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐       │
│  │              TranslationManager                   │       │
│  │  - 翻訳リクエスト管理                             │       │
│  │  - エンジン切替制御                               │       │
│  │  - 結果キャッシュ                                 │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ OnDevice    │  │ Cloud LLM   │  │ Hybrid      │         │
│  │ Translator  │  │ Translator  │  │ Translator  │         │
│  │ (Apple)     │  │ (GPT/Claude)│  │ (Fallback)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌──────────────────────────────────────────────────┐       │
│  │             Context Manager                       │       │
│  │  - 会話履歴管理                                   │       │
│  │  - 文脈ウィンドウ制御                             │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────┐       │
│  │             Glossary Manager                      │       │
│  │  - 専門用語適用                                   │       │
│  │  - 前後処理                                       │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Protocol定義

```swift
// MARK: - Translator Protocol

protocol TranslatorProtocol {
    var translationStream: AnyPublisher<TranslationResult, Error> { get }

    func translate(_ request: TranslationRequest) async throws -> TranslationResult
    func translateStreaming(_ request: TranslationRequest) -> AnyPublisher<TranslationResult, Error>
    func cancel()
}

protocol ContextManagerProtocol {
    func addTurn(_ turn: ConversationTurn)
    func getContext() -> ConversationContext
    func clear()
}

protocol GlossaryManagerProtocol {
    func loadGlossary(_ glossary: Glossary)
    func applyGlossary(to text: String) -> String
    func getAppliedTerms() -> [String]
}
```

### 4.3 主要クラス実装

```swift
// MARK: - TranslationManager

final class TranslationManager: TranslatorProtocol {
    // 依存関係
    private let onDeviceTranslator: OnDeviceTranslator
    private let cloudTranslator: CloudLLMTranslator
    private let contextManager: ContextManagerProtocol
    private let glossaryManager: GlossaryManagerProtocol

    // 設定
    private var config: TranslationConfig

    // ストリーム
    private let resultSubject = PassthroughSubject<TranslationResult, Error>()
    var translationStream: AnyPublisher<TranslationResult, Error> {
        resultSubject.eraseToAnyPublisher()
    }

    // MARK: - 翻訳実行

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        // 専門用語の前処理
        let processedText = glossaryManager.applyGlossary(to: request.text)

        // 文脈の取得
        let context = contextManager.getContext()

        // 翻訳エンジン選択
        let result: TranslationResult
        if config.preferOnDevice && await isOnDeviceAvailable(for: request) {
            result = try await onDeviceTranslator.translate(
                processedText,
                from: request.sourceLanguage,
                to: request.targetLanguage
            )
        } else {
            result = try await cloudTranslator.translate(
                processedText,
                from: request.sourceLanguage,
                to: request.targetLanguage,
                context: context
            )
        }

        // 会話履歴に追加
        contextManager.addTurn(ConversationTurn(
            speaker: .speaker1,
            originalText: request.text,
            translatedText: result.translatedText,
            timestamp: Date()
        ))

        return result
    }

    func translateStreaming(_ request: TranslationRequest) -> AnyPublisher<TranslationResult, Error> {
        // ストリーミング翻訳の実装
        return cloudTranslator.translateStreaming(request)
    }
}
```

---

## 5. Apple Translation Framework実装

### 5.1 オンデバイス翻訳

```swift
import Translation

final class OnDeviceTranslator {
    private var session: TranslationSession?

    // MARK: - 言語パック管理

    func checkLanguageAvailability(
        source: Locale.Language,
        target: Locale.Language
    ) async -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        return await availability.status(from: source, to: target)
    }

    func downloadLanguagePack(
        source: Locale.Language,
        target: Locale.Language
    ) async throws {
        let config = TranslationSession.Configuration(source: source, target: target)
        // ダウンロードはTranslationSession初期化時に自動実行
        session = try await TranslationSession(configuration: config)
    }

    // MARK: - 翻訳

    func translate(
        _ text: String,
        from source: Locale,
        to target: Locale
    ) async throws -> TranslationResult {
        let startTime = Date()

        let config = TranslationSession.Configuration(
            source: Locale.Language(identifier: source.identifier),
            target: Locale.Language(identifier: target.identifier)
        )

        let session = try await TranslationSession(configuration: config)
        let response = try await session.translate(text)

        let processingTime = Date().timeIntervalSince(startTime)

        return TranslationResult(
            originalText: text,
            translatedText: response.targetText,
            isFinal: true,
            confidence: 0.9,  // Apple Translationは信頼度を提供しない
            timestamp: Date(),
            processingTime: processingTime,
            glossaryApplied: []
        )
    }
}
```

### 5.2 SwiftUI統合

```swift
struct TranslationView: View {
    @State private var sourceText = ""
    @State private var translatedText = ""
    @State private var translationConfig: TranslationSession.Configuration?

    var body: some View {
        VStack {
            TextField("入力", text: $sourceText)

            Text(translatedText)
                .foregroundColor(.secondary)

            Button("翻訳") {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "ja"),
                    target: Locale.Language(identifier: "en")
                )
            }
        }
        .translationTask(translationConfig) { session in
            do {
                let response = try await session.translate(sourceText)
                translatedText = response.targetText
            } catch {
                translatedText = "翻訳エラー"
            }
        }
    }
}
```

---

## 6. Cloud LLM翻訳実装

### 6.1 OpenAI/Claude API統合

```swift
final class CloudLLMTranslator {
    private let apiClient: LLMAPIClient
    private let contextManager: ContextManagerProtocol

    // MARK: - 初期化

    init(provider: LLMProvider) {
        switch provider {
        case .openAI:
            self.apiClient = OpenAIClient()
        case .claude:
            self.apiClient = ClaudeClient()
        }
    }

    // MARK: - 翻訳

    func translate(
        _ text: String,
        from source: Locale,
        to target: Locale,
        context: ConversationContext
    ) async throws -> TranslationResult {
        let startTime = Date()

        // プロンプト構築
        let prompt = buildTranslationPrompt(
            text: text,
            source: source,
            target: target,
            context: context
        )

        // API呼び出し
        let response = try await apiClient.complete(prompt: prompt)

        let processingTime = Date().timeIntervalSince(startTime)

        return TranslationResult(
            originalText: text,
            translatedText: response.text,
            isFinal: true,
            confidence: 0.95,
            timestamp: Date(),
            processingTime: processingTime,
            glossaryApplied: []
        )
    }

    // MARK: - プロンプト構築

    private func buildTranslationPrompt(
        text: String,
        source: Locale,
        target: Locale,
        context: ConversationContext
    ) -> String {
        var prompt = """
        あなたはプロの同時通訳者です。以下のテキストを\(source.identifier)から\(target.identifier)に翻訳してください。

        ルール:
        - 自然で流暢な翻訳を心がける
        - 文脈を考慮する
        - 専門用語は適切に訳す
        - 余計な説明は加えず、翻訳文のみを返す

        """

        // 文脈を追加
        if !context.turns.isEmpty {
            prompt += "会話の文脈:\n"
            for turn in context.turns.suffix(5) {
                prompt += "- \(turn.originalText) → \(turn.translatedText)\n"
            }
            prompt += "\n"
        }

        prompt += "翻訳対象: \(text)"

        return prompt
    }

    // MARK: - ストリーミング翻訳

    func translateStreaming(
        _ request: TranslationRequest
    ) -> AnyPublisher<TranslationResult, Error> {
        let subject = PassthroughSubject<TranslationResult, Error>()

        Task {
            do {
                let stream = try await apiClient.streamComplete(prompt: buildTranslationPrompt(
                    text: request.text,
                    source: request.sourceLanguage,
                    target: request.targetLanguage,
                    context: contextManager.getContext()
                ))

                var accumulatedText = ""

                for try await chunk in stream {
                    accumulatedText += chunk

                    subject.send(TranslationResult(
                        originalText: request.text,
                        translatedText: accumulatedText,
                        isFinal: false,
                        confidence: 0.0,
                        timestamp: Date(),
                        processingTime: 0,
                        glossaryApplied: []
                    ))
                }

                // 最終結果
                subject.send(TranslationResult(
                    originalText: request.text,
                    translatedText: accumulatedText,
                    isFinal: true,
                    confidence: 0.95,
                    timestamp: Date(),
                    processingTime: 0,
                    glossaryApplied: []
                ))

                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }
}

// MARK: - LLM Provider

enum LLMProvider {
    case openAI
    case claude

    var endpoint: URL {
        switch self {
        case .openAI:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .claude:
            return URL(string: "https://api.anthropic.com/v1/messages")!
        }
    }
}
```

---

## 7. Wait-k ストリーミング戦略

### 7.1 アルゴリズム

```swift
final class WaitKTranslator {
    private let k: Int  // 待機単語数
    private var buffer: [String] = []
    private var translatedSegments: [String] = []

    init(k: Int = 3) {
        self.k = k
    }

    // MARK: - ストリーミング処理

    func processToken(_ token: String) -> String? {
        buffer.append(token)

        // k単語以上蓄積されたら翻訳開始
        if buffer.count >= k {
            let segment = buffer.prefix(k).joined(separator: " ")
            buffer.removeFirst(k)

            return translateSegment(segment)
        }

        return nil
    }

    func flush() -> String {
        // 残りのバッファを全て翻訳
        let remaining = buffer.joined(separator: " ")
        buffer.removeAll()
        return translateSegment(remaining)
    }

    private func translateSegment(_ segment: String) -> String {
        // 実際の翻訳処理
        // ...
        return segment
    }
}
```

### 7.2 適応型Wait-k

```swift
struct AdaptiveWaitKConfig {
    let minK: Int = 2
    let maxK: Int = 5
    let sentenceEndMarkers: Set<Character> = ["。", ".", "!", "?", "！", "？"]

    func calculateK(for text: String) -> Int {
        // 文末が検出されたらすぐに翻訳
        if let lastChar = text.last, sentenceEndMarkers.contains(lastChar) {
            return minK
        }

        // テキスト長に基づいて調整
        let length = text.count
        if length < 10 {
            return maxK
        } else if length < 20 {
            return (minK + maxK) / 2
        } else {
            return minK
        }
    }
}
```

---

## 8. 専門用語辞書管理

### 8.1 データモデル

```swift
import SwiftData

@Model
final class GlossaryModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceLanguage: String
    var targetLanguage: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var entries: [GlossaryEntryModel]

    init(name: String, sourceLanguage: String, targetLanguage: String) {
        self.id = UUID()
        self.name = name
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdAt = Date()
        self.updatedAt = Date()
        self.entries = []
    }
}

@Model
final class GlossaryEntryModel {
    var source: String
    var target: String
    var caseSensitive: Bool
    var context: String?

    init(source: String, target: String, caseSensitive: Bool = false, context: String? = nil) {
        self.source = source
        self.target = target
        self.caseSensitive = caseSensitive
        self.context = context
    }
}
```

### 8.2 辞書適用

```swift
final class GlossaryManager: GlossaryManagerProtocol {
    private var activeGlossary: Glossary?
    private var appliedTerms: [String] = []

    func loadGlossary(_ glossary: Glossary) {
        self.activeGlossary = glossary
    }

    func applyGlossary(to text: String) -> String {
        guard let glossary = activeGlossary else { return text }

        appliedTerms.removeAll()
        var processedText = text

        // 長い用語から順に適用（部分一致の問題を回避）
        let sortedEntries = glossary.entries.sorted { $0.source.count > $1.source.count }

        for entry in sortedEntries {
            let options: String.CompareOptions = entry.caseSensitive ? [] : .caseInsensitive

            if processedText.range(of: entry.source, options: options) != nil {
                // マーカーで囲む（翻訳時に保持するため）
                processedText = processedText.replacingOccurrences(
                    of: entry.source,
                    with: "[[TERM:\(entry.target)]]",
                    options: options
                )
                appliedTerms.append(entry.source)
            }
        }

        return processedText
    }

    func getAppliedTerms() -> [String] {
        return appliedTerms
    }
}
```

---

## 9. テスト仕様

### 9.1 ユニットテスト

```swift
final class TranslationManagerTests: XCTestCase {
    var sut: TranslationManager!

    override func setUp() {
        sut = TranslationManager(config: .default)
    }

    func test_translate_shouldReturnTranslatedText() async throws {
        // Given
        let request = TranslationRequest(
            text: "こんにちは",
            sourceLanguage: Locale(identifier: "ja-JP"),
            targetLanguage: Locale(identifier: "en-US"),
            context: nil,
            glossary: nil,
            isPartial: false
        )

        // When
        let result = try await sut.translate(request)

        // Then
        XCTAssertFalse(result.translatedText.isEmpty)
        XCTAssertTrue(result.isFinal)
    }

    func test_translate_withContext_shouldConsiderPreviousTurns() async throws {
        // Given
        let context = [
            ConversationTurn(
                speaker: .speaker1,
                originalText: "あの赤い車を見て",
                translatedText: "Look at that red car",
                timestamp: Date()
            )
        ]

        let request = TranslationRequest(
            text: "あれはいくらですか？",
            sourceLanguage: Locale(identifier: "ja-JP"),
            targetLanguage: Locale(identifier: "en-US"),
            context: context,
            glossary: nil,
            isPartial: false
        )

        // When
        let result = try await sut.translate(request)

        // Then
        // 「あれ」が「赤い車」を指すことを理解した翻訳になっている
        XCTAssertTrue(result.translatedText.lowercased().contains("car") ||
                      result.translatedText.lowercased().contains("it"))
    }
}
```

### 9.2 翻訳品質テスト

| テスト項目 | 評価方法 | 目標値 |
|-----------|----------|--------|
| BLEU スコア | 標準テストセット | > 40 |
| 処理時間 | 平均レスポンス時間 | < 500ms |
| 文脈理解 | 指示語テスト | > 85% 正解 |
| 専門用語 | 辞書適用率 | 100% |

---

## 10. エラーハンドリング

```swift
enum TranslationError: Error, LocalizedError {
    case languageNotSupported(source: Locale, target: Locale)
    case networkError(underlying: Error)
    case rateLimitExceeded
    case contextTooLong
    case translationFailed(reason: String)
    case languagePackNotDownloaded

    var errorDescription: String? {
        switch self {
        case .languageNotSupported(let source, let target):
            return "\(source.identifier) → \(target.identifier) の翻訳はサポートされていません"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "APIレート制限を超過しました"
        case .contextTooLong:
            return "文脈が長すぎます"
        case .translationFailed(let reason):
            return "翻訳に失敗しました: \(reason)"
        case .languagePackNotDownloaded:
            return "言語パックがダウンロードされていません"
        }
    }
}
```

---

## 11. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
