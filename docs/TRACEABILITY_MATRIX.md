# LiveLingo - 機能要件-ソースコードトレーサビリティマトリクス

## ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | 機能要件-ソースコードトレーサビリティマトリクス |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-25 |
| 関連Issue | #140, #141, #142, #143, #144 |

---

## 1. STTモジュール トレーサビリティ

### 1.1 F-STT-001: リアルタイム音声認識

| 項目 | 詳細 |
|------|------|
| **実装状態** | **実装済み** |
| **ソースファイル** | `Sources/Services/STT/AppleSTTService.swift` |
| **行番号** | 33-99 |
| **実装関数** | `startRecognition(language:)` |

#### コード対応箇所

| 要件仕様 | ソースコード行 | 実装詳細 |
|---------|--------------|----------|
| 音声認識開始 | L33-99 | `startRecognition()` async function |
| SFSpeechRecognizer初期化 | L45-51 | `SFSpeechRecognizer(locale:)` |
| 部分結果出力 | L64 | `shouldReportPartialResults = true` |
| オンデバイス認識 | L65 | `requiresOnDeviceRecognition` |
| 自動句読点 | L67-69 | `addsPunctuation = true` (iOS 16+) |
| AudioEngine設定 | L116-135 | `setupAudioEngine()` |
| バッファサイズ | L124 | `bufferSize: 1024` |
| 認識結果処理 | L137-186 | `startRecognitionTask()` |
| 信頼度計算 | L188-194 | `calculateConfidence()` |
| セグメント抽出 | L196-205 | `extractSegments()` |

#### RecognitionResult構造体

| 要件フィールド | 実装行 | 実装状態 |
|---------------|-------|---------|
| `text: String` | L170 | 実装済み |
| `isFinal: Bool` | L171 | 実装済み |
| `confidence: Float` | L173 | 実装済み |
| `timestamp: Date` | L175 | 実装済み |
| `alternatives: [String]` | - | **未実装** |
| `detectedLanguage: Locale?` | - | **未実装** |

---

### 1.2 F-STT-002: 間（ポーズ）検出

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **プロトコル定義** | `Sources/Domain/Protocols/STTServiceProtocol.swift` L38-46 |
| **実装クラス** | なし |

#### 必要な実装

| 要件コンポーネント | 期待されるファイル | 状態 |
|-------------------|------------------|------|
| `PauseDetectorProtocol` | STTServiceProtocol.swift L38-46 | プロトコルのみ |
| `PauseDetectionConfig` | - | **未実装** |
| `PauseType` enum | - | **未実装** |
| 無音判定ロジック | - | **未実装** |

```swift
// 要件定義書で期待される構造体（未実装）
struct PauseDetectionConfig {
    let shortPauseThreshold: TimeInterval = 0.3
    let longPauseThreshold: TimeInterval = 0.8
    let silenceThreshold: Float = -40.0
}

enum PauseType {
    case short      // 意味の区切り
    case long       // 文末
    case utteranceEnd  // 発話終了
}
```

---

### 1.3 F-STT-003: 言語自動検出

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **必要なソース** | 新規ファイル必要 |

#### 要件との差分

| 要件項目 | 現状 |
|---------|------|
| 発話開始から500ms以内に言語判定 | 実装なし |
| 判定精度90%以上 | 実装なし |
| サポート言語（Phase 1: 日英中韓） | 言語選択は手動のみ |

---

### 1.4 F-STT-004: デュアルスピーカー認識

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **プロトコル定義** | `Sources/Domain/Protocols/STTServiceProtocol.swift` L49-57 |
| **実装クラス** | なし |

#### プロトコル対応（定義のみ）

```swift
// STTServiceProtocol.swift L49-57
public protocol SpeakerDiarizerProtocol: Sendable {
    func identifySpeaker(for segment: Data) async -> SpeakerID
    func resetProfiles()
}
```

---

## 2. 翻訳エンジン トレーサビリティ

### 2.1 F-TRN-001: リアルタイム翻訳

| 項目 | 詳細 |
|------|------|
| **実装状態** | **実装済み** |
| **ソースファイル** | `Sources/Services/Translation/AppleTranslationService.swift` |
| **行番号** | 16-55 |
| **実装関数** | `translate(_:from:to:)` |

#### コード対応箇所

| 要件仕様 | ソースコード行 | 実装詳細 |
|---------|--------------|----------|
| 翻訳リクエスト処理 | L16-55 | `translate()` async function |
| 空テキスト処理 | L21-30 | 空文字列の早期リターン |
| 言語ペア確認 | L33-38 | `isAvailable(from:to:)` |
| 翻訳実行 | L41-45 | `performTranslation()` |
| 翻訳結果構築 | L47-54 | `TranslationResult` 生成 |
| サポート言語ペア | L77-90 | hardcoded set |
| 信頼度計算 | L115-122 | `calculateConfidence()` |

#### TranslationResult構造体

| 要件フィールド | 実装行 | 実装状態 |
|---------------|-------|---------|
| `originalText: String` | L48 | 実装済み |
| `translatedText: String` | L49 | 実装済み |
| `isFinal: Bool` | - | **未実装** |
| `confidence: Float` | L53 | 実装済み |
| `processingTime: TimeInterval` | - | **未実装** |
| `glossaryApplied: [String]` | - | **未実装** |

---

### 2.2 F-TRN-002: 文脈保持翻訳

| 項目 | 詳細 |
|------|------|
| **実装状態** | **部分実装** |
| **ソースファイル** | `Sources/Services/Translation/AppleTranslationService.swift` |
| **行番号** | 201-215 (構造体のみ) |

#### 実装状況

| コンポーネント | ファイル:行 | 状態 |
|--------------|------------|------|
| `TranslationContext` 構造体 | L201-215 | 定義のみ |
| `TranslationDomain` enum | L217-224 | 定義のみ |
| 文脈を使用した翻訳ロジック | - | **未実装** |
| 会話履歴管理 | - | **未実装** |
| 指示語解釈 | - | **未実装** |

```swift
// AppleTranslationService.swift L201-215 (定義のみ)
public struct TranslationContext: Sendable {
    public let domain: TranslationDomain
    public let glossary: Glossary?
    public let previousTranslations: [TranslationResult]
    // ...
}
```

---

### 2.3 F-TRN-003: ストリーミング翻訳

| 項目 | 詳細 |
|------|------|
| **実装状態** | **部分実装（非最適）** |
| **ソースファイル** | `Sources/Services/Translation/AppleTranslationService.swift` |
| **行番号** | 57-73 |

#### 実装状況

| 要件項目 | 実装状態 | 備考 |
|---------|---------|------|
| `streamTranslate()` 関数 | 存在 | 実質的に通常翻訳のラッパー |
| Wait-k戦略 | **未実装** | 要件定義書のWait-k未対応 |
| 逐次出力 | **未実装** | 一括出力のみ |
| フラッシュ間隔制御 | **未実装** | - |

```swift
// AppleTranslationService.swift L57-73
public func streamTranslate(...) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            // 通常翻訳を呼び出すだけ（真のストリーミングではない）
            let result = try await translate(...)
            continuation.yield(result.translatedText)
            continuation.finish()
        }
    }
}
```

---

### 2.4 F-TRN-004: 専門用語辞書

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **参照箇所** | `Sources/Services/Translation/AppleTranslationService.swift` L203 |

#### 必要な実装

| 要件コンポーネント | 状態 |
|-------------------|------|
| `Glossary` モデル | **未実装** |
| `GlossaryEntry` モデル | **未実装** |
| `GlossaryManager` | **未実装** |
| 辞書適用ロジック | **未実装** |
| SwiftData永続化 | **未実装** |

---

## 3. TTSモジュール トレーサビリティ

### 3.1 F-TTS-001: リアルタイム音声合成

| 項目 | 詳細 |
|------|------|
| **実装状態** | **実装済み** |
| **ソースファイル** | `Sources/Services/TTS/AppleTTSService.swift` |
| **行番号** | 54-72 |
| **実装関数** | `speak(_:voice:)` |

#### コード対応箇所

| 要件仕様 | ソースコード行 | 実装詳細 |
|---------|--------------|----------|
| speak関数 | L54-72 | `speak()` async throws |
| 空テキスト処理 | L55-57 | 早期リターン |
| 現在再生停止 | L60-62 | `stopPlayback()` |
| Utterance作成 | L64-65 | `createUtterance()` |
| 再生状態管理 | L66 | `isSpeaking = true` |
| Continuation | L68-71 | `withCheckedThrowingContinuation` |
| 停止 | L79-84 | `stopPlayback()` |
| 一時停止 | L86-88 | `pause()` |
| 再開 | L90-92 | `resume()` |

---

### 3.2 F-TTS-002: 音声選択

| 項目 | 詳細 |
|------|------|
| **実装状態** | **実装済み** |
| **ソースファイル** | `Sources/Services/TTS/AppleTTSService.swift` |
| **行番号** | 96-131 |

#### コード対応箇所

| 要件仕様 | ソースコード行 | 実装詳細 |
|---------|--------------|----------|
| 利用可能音声取得 | L96-117 | `availableVoices(for:)` |
| 言語フィルタリング | L98 | `language.starts(with:)` |
| VoiceOption変換 | L99-109 | map処理 |
| 品質順ソート | L110-116 | premium優先ソート |
| デフォルト音声 | L119-131 | `defaultVoice(for:)` |
| 音声品質マッピング | L154-165 | `mapVoiceQuality()` |
| 性別マッピング | L167-181 | `mapGender()` iOS 17+ |

---

### 3.3 F-TTS-003: Personal Voice対応

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **必要なソース** | 新規ファイルまたは拡張 |

#### 要件との差分

| 要件項目 | 現状 |
|---------|------|
| iOS 17+ Personal Voice API | 実装なし |
| `AVSpeechSynthesizer.personalVoiceAuthorizationStatus` | 未使用 |
| Personal Voice認証フロー | 実装なし |
| Personal Voice一覧取得 | 実装なし |

```swift
// 要件定義書で期待される実装（未実装）
final class PersonalVoiceManager {
    func isPersonalVoiceAvailable() -> Bool
    func requestPersonalVoiceAuthorization() async -> Bool
    func getPersonalVoices() -> [AVSpeechSynthesisVoice]
    func speakWithPersonalVoice(text: String) async throws
}
```

---

### 3.4 F-TTS-004: CoeFont AI音声統合

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **必要なソース** | `Sources/Services/TTS/CoeFontTTSService.swift` |

#### 必要な実装

| コンポーネント | 状態 |
|--------------|------|
| `CoeFontAPIClient` | **未実装** |
| HMAC-SHA256署名生成 | **未実装** |
| `synthesize()` API呼び出し | **未実装** |
| `getAvailableVoices()` API呼び出し | **未実装** |
| `CoeFontVoice` モデル | **未実装** |
| レート制限処理 | **未実装** |

---

## 4. 概要機能 (F001-F012) トレーサビリティ

### 4.1 コア機能実装状況

| 機能ID | 機能名 | 実装状態 | ソースファイル | 行番号 |
|-------|--------|---------|--------------|-------|
| F001 | リアルタイム音声認識 | **実装済み** | AppleSTTService.swift | L33-99 |
| F002 | リアルタイム翻訳 | **実装済み** | AppleTranslationService.swift | L16-55 |
| F003 | 音声合成出力 | **実装済み** | AppleTTSService.swift | L54-72 |
| F004 | 8言語サポート | **部分実装** | SupportedLanguage.swift | 全体 |
| F005 | 双方向通訳 | **部分実装** | - | Protocol定義のみ |

### 4.2 拡張機能実装状況

| 機能ID | 機能名 | 実装状態 | ソースファイル | 備考 |
|-------|--------|---------|--------------|------|
| F006 | カスタム音声作成 | **未実装** | - | Personal Voice, CoeFont |
| F007 | 会話履歴保存 | **未実装** | - | SwiftData必要 |
| F008 | 専門用語辞書 | **未実装** | - | Glossary未実装 |
| F009 | オフラインモード | **部分実装** | AppleSTTService.swift L65 | STTのみ |

### 4.3 付加機能実装状況

| 機能ID | 機能名 | 実装状態 | ソースファイル | 備考 |
|-------|--------|---------|--------------|------|
| F010 | Apple Watch連携 | **未実装** | - | watchOS Target未作成 |
| F011 | ウィジェット対応 | **未実装** | - | WidgetKit未統合 |
| F012 | Siriショートカット | **未実装** | - | AppIntents未実装 |

---

## 5. 未実装機能サマリー

### 5.1 優先度P0（必須）- 未実装

| 機能ID | 機能名 | 影響範囲 | 推定工数 |
|-------|--------|---------|---------|
| F-STT-002 | 間検出 | STT精度向上 | 3日 |
| F-TRN-002 | 文脈保持翻訳 | 翻訳品質 | 5日 |
| F-TRN-003 | ストリーミング翻訳 | 遅延削減 | 5日 |

### 5.2 優先度P1 - 未実装

| 機能ID | 機能名 | 影響範囲 | 推定工数 |
|-------|--------|---------|---------|
| F-STT-003 | 言語自動検出 | UX向上 | 3日 |
| F-STT-004 | デュアルスピーカー | 双方向通訳 | 7日 |
| F-TRN-004 | 専門用語辞書 | 専門性 | 5日 |
| F-TTS-003 | Personal Voice | カスタム音声 | 3日 |
| F-TTS-004 | CoeFont API | 音声品質 | 5日 |

### 5.3 優先度P2 - 未実装

| 機能ID | 機能名 | 影響範囲 | 推定工数 |
|-------|--------|---------|---------|
| F010 | Apple Watch連携 | エコシステム | 7日 |
| F011 | ウィジェット対応 | アクセシビリティ | 3日 |
| F012 | Siriショートカット | アクセシビリティ | 2日 |

---

## 6. 依存関係マップ

```
F001 (STT) ─────┬───▶ F-STT-002 (間検出) ─▶ F-TRN-003 (ストリーミング翻訳)
                │
                └───▶ F-STT-003 (言語自動検出)
                │
                └───▶ F-STT-004 (デュアルスピーカー) ─▶ F005 (双方向通訳)

F002 (翻訳) ────┬───▶ F-TRN-002 (文脈保持) ─▶ 翻訳品質向上
                │
                └───▶ F-TRN-003 (ストリーミング) ─▶ 遅延削減
                │
                └───▶ F-TRN-004 (辞書) ─▶ F008 (専門用語辞書)

F003 (TTS) ─────┬───▶ F-TTS-003 (Personal Voice) ─▶ F006 (カスタム音声)
                │
                └───▶ F-TTS-004 (CoeFont) ─▶ F006 (カスタム音声)
```

---

## 7. API統合 トレーサビリティ

### 7.1 F-API-001: Google Gemini Live API統合

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装（2026年計画）** |
| **要件定義書** | `docs/implementation-plan/01-api-comparison.md` Section 2, 6.3, 7 |
| **計画フェーズ** | Phase 3: Premium (2026) |

#### 要件仕様

| 機能 | 詳細 | 実装状態 |
|------|------|---------|
| リアルタイムSTT | 24言語対応 | **未実装** |
| リアルタイム翻訳 | 70言語以上 | **未実装** |
| TTS | 話者特性保持 | **未実装** |
| 割り込み対応 | Barge-in | **未実装** |
| 連続リスニングモード | 自動言語検出 | **未実装** |
| 双方向会話モード | 自動出力言語切替 | **未実装** |

#### iOS SDK状況
- Android: ベータ版利用可能（2025年12月〜）
- iOS: **2026年対応予定**
- 統合方法: Firebase AI Logic SDK / Pipecat WebSocket

#### 関連Issue
- #156: Gemini Live API統合

---

### 7.2 F-API-002: Google Live Speech Client

| 項目 | 詳細 |
|------|------|
| **実装状態** | **未実装** |
| **要件定義書** | `docs/10-api-network.md` Section 6 (L383-490) |
| **要件定義書** | `docs/08-performance.md` Section (L85-105) |

#### 要件仕様（10-api-network.md）

```swift
// L392-429 で定義されているクライアント仕様
final class GoogleSpeechClient {
    private let baseURL = URL(string: "https://speech.googleapis.com/v1/")!
    func transcribe(_ audioData: Data) async throws -> TranscriptionResult
}
```

#### 実装状態
- `GoogleSpeechClient` クラス: **未実装**
- `GoogleSpeechError` enum: **未実装**
- ベンチマーク: **未実装**

---

## 8. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-25 | 初版作成 | AI Agent |
| 1.1.0 | 2024-12-25 | API統合セクション追加（Gemini Live API） | AI Agent |

---

*このドキュメントは機能要件定義書とソースコードの対応関係を追跡するために作成されました。*
*関連Issue: #140, #141, #142, #143, #144*
