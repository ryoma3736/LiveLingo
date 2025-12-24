# LiveLingo - 多言語サポート機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | 多言語サポート機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #8 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

8言語間の双方向音声通訳を実現し、各言語の特性に応じた最適な処理を行う。

### 2.2 主要責務

1. 対応言語の管理
2. 言語ごとのSTT/TTS設定
3. 言語パックのダウンロード管理
4. 言語自動検出
5. 方言・アクセント対応

---

## 3. 対応言語一覧

### 3.1 Phase 1（リリース時）

| 言語 | コード | 地域 | STT | 翻訳 | TTS | オフライン |
|------|--------|------|-----|------|-----|-----------|
| 日本語 | ja-JP | 日本 | Yes | Yes | Yes | 部分的 |
| 英語（米国） | en-US | 米国 | Yes | Yes | Yes | Yes |
| 英語（英国） | en-GB | 英国 | Yes | Yes | Yes | Yes |
| 中国語（簡体） | zh-CN | 中国 | Yes | Yes | Yes | 部分的 |
| 中国語（繁体） | zh-TW | 台湾 | Yes | Yes | Yes | 部分的 |
| 韓国語 | ko-KR | 韓国 | Yes | Yes | Yes | 部分的 |

### 3.2 Phase 2

| 言語 | コード | 地域 | STT | 翻訳 | TTS | オフライン |
|------|--------|------|-----|------|-----|-----------|
| フランス語 | fr-FR | フランス | Yes | Yes | Yes | 部分的 |
| スペイン語（スペイン） | es-ES | スペイン | Yes | Yes | Yes | 部分的 |
| スペイン語（メキシコ） | es-MX | メキシコ | Yes | Yes | Yes | 部分的 |
| ベトナム語 | vi-VN | ベトナム | Yes | Yes | Yes | No |
| ポルトガル語（ブラジル） | pt-BR | ブラジル | Yes | Yes | Yes | 部分的 |

---

## 4. 機能要件

### 4.1 コア機能

#### F-LNG-001: 言語ペア管理

| 項目 | 仕様 |
|------|------|
| 機能ID | F-LNG-001 |
| 機能名 | 言語ペア管理 |
| 説明 | 翻訳元・翻訳先言語の管理 |
| 優先度 | P0（必須） |

**データモデル**:
```swift
struct SupportedLanguage: Identifiable, Codable, Hashable {
    let id: String                  // "ja-JP"
    let code: String                // "ja"
    let region: String              // "JP"
    let localizedName: String       // "日本語"
    let englishName: String         // "Japanese"
    let nativeName: String          // "日本語"
    let flagIcon: String            // "flag-jp" (SVG)
    let isRTL: Bool                 // 右から左への言語か
    let sttSupported: Bool
    let translationSupported: Bool
    let ttsSupported: Bool
    let offlineSupported: Bool
}

struct LanguagePair: Identifiable, Codable {
    var id: String { "\(source.id)-\(target.id)" }
    let source: SupportedLanguage
    let target: SupportedLanguage
}
```

#### F-LNG-002: 言語パック管理

| 項目 | 仕様 |
|------|------|
| 機能ID | F-LNG-002 |
| 機能名 | 言語パック管理 |
| 説明 | オフライン翻訳用言語パックの管理 |
| 優先度 | P1 |

**言語パック情報**:
```swift
struct LanguagePack: Identifiable {
    let id: String
    let language: SupportedLanguage
    let size: Int64                  // バイト数
    let version: String
    let downloadStatus: DownloadStatus
    let features: LanguagePackFeatures
}

struct LanguagePackFeatures {
    let sttModel: Bool               // 音声認識モデル
    let translationModel: Bool       // 翻訳モデル
    let ttsVoices: [String]          // 利用可能な音声
}

enum DownloadStatus {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case updateAvailable
    case error(Error)
}
```

#### F-LNG-003: 言語自動検出

| 項目 | 仕様 |
|------|------|
| 機能ID | F-LNG-003 |
| 機能名 | 言語自動検出 |
| 説明 | 音声入力から言語を自動判定 |
| 優先度 | P1 |

**検出設定**:
```swift
struct LanguageDetectionConfig {
    let enabled: Bool = true
    let confidenceThreshold: Float = 0.8  // 80%以上で確定
    let maxDetectionTime: TimeInterval = 2.0  // 最大2秒で判定
    let candidateLanguages: [SupportedLanguage]  // 検出対象言語
}
```

---

## 5. 技術設計

### 5.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                  Language Support Module                     │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐       │
│  │           LanguageManager                         │       │
│  │  - 対応言語一覧管理                               │       │
│  │  - 言語ペア管理                                   │       │
│  │  - 言語設定の永続化                               │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Language    │  │ Language    │  │ Language    │         │
│  │ Pack Manager│  │ Detector    │  │ Config      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌──────────────────────────────────────────────────┐       │
│  │        STT / Translation / TTS Modules           │       │
│  │  (言語固有の設定を適用)                          │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 主要クラス実装

```swift
import Foundation
import Combine
import Translation

// MARK: - Language Manager

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var availableLanguages: [SupportedLanguage] = []
    @Published private(set) var languagePacks: [LanguagePack] = []
    @Published var currentPair: LanguagePair

    private let storage: LanguageStorageProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初期化

    private init() {
        self.storage = LanguageStorage()
        self.currentPair = storage.loadLastPair() ?? LanguagePair.default

        loadSupportedLanguages()
        loadLanguagePacks()
    }

    // MARK: - 対応言語読み込み

    private func loadSupportedLanguages() {
        // Phase 1 言語
        availableLanguages = [
            SupportedLanguage(
                id: "ja-JP",
                code: "ja",
                region: "JP",
                localizedName: NSLocalizedString("language_japanese", comment: ""),
                englishName: "Japanese",
                nativeName: "日本語",
                flagIcon: "flag-jp",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: true
            ),
            SupportedLanguage(
                id: "en-US",
                code: "en",
                region: "US",
                localizedName: NSLocalizedString("language_english_us", comment: ""),
                englishName: "English (US)",
                nativeName: "English",
                flagIcon: "flag-us",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: true
            ),
            SupportedLanguage(
                id: "zh-CN",
                code: "zh",
                region: "CN",
                localizedName: NSLocalizedString("language_chinese_simplified", comment: ""),
                englishName: "Chinese (Simplified)",
                nativeName: "简体中文",
                flagIcon: "flag-cn",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: true
            ),
            SupportedLanguage(
                id: "ko-KR",
                code: "ko",
                region: "KR",
                localizedName: NSLocalizedString("language_korean", comment: ""),
                englishName: "Korean",
                nativeName: "한국어",
                flagIcon: "flag-kr",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: true
            ),
            // Phase 2 言語
            SupportedLanguage(
                id: "fr-FR",
                code: "fr",
                region: "FR",
                localizedName: NSLocalizedString("language_french", comment: ""),
                englishName: "French",
                nativeName: "Français",
                flagIcon: "flag-fr",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: false
            ),
            SupportedLanguage(
                id: "es-ES",
                code: "es",
                region: "ES",
                localizedName: NSLocalizedString("language_spanish", comment: ""),
                englishName: "Spanish",
                nativeName: "Español",
                flagIcon: "flag-es",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: false
            ),
            SupportedLanguage(
                id: "vi-VN",
                code: "vi",
                region: "VN",
                localizedName: NSLocalizedString("language_vietnamese", comment: ""),
                englishName: "Vietnamese",
                nativeName: "Tiếng Việt",
                flagIcon: "flag-vn",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: false
            ),
            SupportedLanguage(
                id: "pt-BR",
                code: "pt",
                region: "BR",
                localizedName: NSLocalizedString("language_portuguese", comment: ""),
                englishName: "Portuguese (Brazil)",
                nativeName: "Português",
                flagIcon: "flag-br",
                isRTL: false,
                sttSupported: true,
                translationSupported: true,
                ttsSupported: true,
                offlineSupported: false
            )
        ]
    }

    // MARK: - 言語ペア設定

    func setLanguagePair(source: SupportedLanguage, target: SupportedLanguage) {
        currentPair = LanguagePair(source: source, target: target)
        storage.saveLastPair(currentPair)
    }

    func swapLanguages() {
        let newPair = LanguagePair(source: currentPair.target, target: currentPair.source)
        currentPair = newPair
        storage.saveLastPair(newPair)
    }

    // MARK: - 言語パック管理

    func checkLanguagePackAvailability() async {
        let availability = LanguageAvailability()

        for language in availableLanguages {
            let status = await availability.status(
                from: Locale.Language(identifier: "ja"),
                to: Locale.Language(identifier: language.code)
            )

            // ステータスを更新
            updateLanguagePackStatus(for: language, status: status)
        }
    }

    func downloadLanguagePack(for language: SupportedLanguage) async throws {
        // Apple Translation Frameworkの言語パックをダウンロード
        let config = TranslationSession.Configuration(
            source: nil,  // 自動検出
            target: Locale.Language(identifier: language.code)
        )

        // ダウンロード進捗を通知
        updatePackDownloadProgress(for: language, progress: 0.0)

        let _ = try await TranslationSession(configuration: config)

        updatePackDownloadProgress(for: language, progress: 1.0)
    }

    private func updatePackDownloadProgress(for language: SupportedLanguage, progress: Double) {
        if let index = languagePacks.firstIndex(where: { $0.language.id == language.id }) {
            languagePacks[index] = LanguagePack(
                id: language.id,
                language: language,
                size: languagePacks[index].size,
                version: languagePacks[index].version,
                downloadStatus: progress >= 1.0 ? .downloaded : .downloading(progress: progress),
                features: languagePacks[index].features
            )
        }
    }
}
```

### 5.3 言語自動検出

```swift
final class LanguageDetector {
    private let config: LanguageDetectionConfig
    private let speechRecognizer: SFSpeechRecognizer

    init(config: LanguageDetectionConfig) {
        self.config = config
        self.speechRecognizer = SFSpeechRecognizer()!
    }

    func detectLanguage(from audioBuffer: AVAudioPCMBuffer) async throws -> DetectionResult {
        var results: [(SupportedLanguage, Float)] = []

        // 各候補言語でスコアを計算
        for language in config.candidateLanguages {
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.id))

            if let recognizer = recognizer, recognizer.isAvailable {
                let score = try await calculateConfidenceScore(
                    for: audioBuffer,
                    using: recognizer
                )
                results.append((language, score))
            }
        }

        // 最高スコアの言語を選択
        let sorted = results.sorted { $0.1 > $1.1 }

        guard let best = sorted.first, best.1 >= config.confidenceThreshold else {
            throw LanguageDetectionError.lowConfidence
        }

        return DetectionResult(
            language: best.0,
            confidence: best.1,
            alternatives: Array(sorted.dropFirst().prefix(2))
        )
    }

    private func calculateConfidenceScore(
        for buffer: AVAudioPCMBuffer,
        using recognizer: SFSpeechRecognizer
    ) async throws -> Float {
        // 認識を実行してスコアを計算
        // ...
        return 0.0
    }
}

struct DetectionResult {
    let language: SupportedLanguage
    let confidence: Float
    let alternatives: [(SupportedLanguage, Float)]
}

enum LanguageDetectionError: Error {
    case lowConfidence
    case noRecognizerAvailable
    case timeout
}
```

---

## 6. 言語固有設定

### 6.1 STT設定

```swift
struct STTLanguageConfig {
    let locale: Locale
    let vocabularyHints: [String]          // ドメイン固有語彙
    let customPronunciations: [String: String]  // カスタム発音
    let punctuationMode: PunctuationMode

    enum PunctuationMode {
        case automatic
        case manual
        case none
    }
}

extension STTLanguageConfig {
    static func config(for language: SupportedLanguage) -> STTLanguageConfig {
        switch language.code {
        case "ja":
            return STTLanguageConfig(
                locale: Locale(identifier: "ja-JP"),
                vocabularyHints: [],
                customPronunciations: [:],
                punctuationMode: .automatic
            )
        case "zh":
            return STTLanguageConfig(
                locale: Locale(identifier: language.id),
                vocabularyHints: [],
                customPronunciations: [:],
                punctuationMode: .automatic
            )
        default:
            return STTLanguageConfig(
                locale: Locale(identifier: language.id),
                vocabularyHints: [],
                customPronunciations: [:],
                punctuationMode: .automatic
            )
        }
    }
}
```

### 6.2 TTS設定

```swift
struct TTSLanguageConfig {
    let locale: Locale
    let defaultVoiceID: String
    let preferredRate: Float
    let preferredPitch: Float
    let ssmlSupport: Bool
}

extension TTSLanguageConfig {
    static func config(for language: SupportedLanguage) -> TTSLanguageConfig {
        switch language.code {
        case "ja":
            return TTSLanguageConfig(
                locale: Locale(identifier: "ja-JP"),
                defaultVoiceID: "com.apple.ttsbundle.Kyoko-compact",
                preferredRate: 0.5,
                preferredPitch: 1.0,
                ssmlSupport: true
            )
        case "en":
            return TTSLanguageConfig(
                locale: Locale(identifier: language.id),
                defaultVoiceID: "com.apple.ttsbundle.Samantha-compact",
                preferredRate: 0.5,
                preferredPitch: 1.0,
                ssmlSupport: true
            )
        case "zh":
            return TTSLanguageConfig(
                locale: Locale(identifier: language.id),
                defaultVoiceID: "com.apple.ttsbundle.Ting-Ting-compact",
                preferredRate: 0.5,
                preferredPitch: 1.0,
                ssmlSupport: true
            )
        default:
            return TTSLanguageConfig(
                locale: Locale(identifier: language.id),
                defaultVoiceID: "",
                preferredRate: 0.5,
                preferredPitch: 1.0,
                ssmlSupport: false
            )
        }
    }
}
```

---

## 7. 言語選択UI

### 7.1 言語選択画面

```swift
struct LanguageSelectionView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Binding var selectedLanguage: SupportedLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("頻繁に使用") {
                    ForEach(languageManager.recentLanguages) { language in
                        LanguageRow(language: language, isSelected: selectedLanguage == language)
                            .onTapGesture {
                                selectedLanguage = language
                                dismiss()
                            }
                    }
                }

                Section("全ての言語") {
                    ForEach(languageManager.availableLanguages) { language in
                        LanguageRow(language: language, isSelected: selectedLanguage == language)
                            .onTapGesture {
                                selectedLanguage = language
                                dismiss()
                            }
                    }
                }
            }
            .navigationTitle("言語を選択")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}

struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 国旗 (SVG)
            Image(language.flagIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(language.localizedName)
                    .font(.body)
                Text(language.nativeName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // オフライン対応バッジ
            if language.offlineSupported {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.green)
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.llPrimary)
            }
        }
        .contentShape(Rectangle())
    }
}
```

---

## 8. 言語パック管理UI

```swift
struct LanguagePacksView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        List {
            ForEach(languageManager.languagePacks) { pack in
                LanguagePackRow(pack: pack) {
                    Task {
                        try? await languageManager.downloadLanguagePack(for: pack.language)
                    }
                }
            }
        }
        .navigationTitle("言語パック")
        .task {
            await languageManager.checkLanguagePackAvailability()
        }
    }
}

struct LanguagePackRow: View {
    let pack: LanguagePack
    let onDownload: () -> Void

    var body: some View {
        HStack {
            Image(pack.language.flagIcon)
                .resizable()
                .frame(width: 32, height: 24)

            VStack(alignment: .leading) {
                Text(pack.language.localizedName)
                Text(formatSize(pack.size))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            switch pack.downloadStatus {
            case .notDownloaded:
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                }

            case .downloading(let progress):
                ProgressView(value: progress)
                    .frame(width: 60)

            case .downloaded:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

            case .updateAvailable:
                Button(action: onDownload) {
                    Image(systemName: "arrow.clockwise.circle")
                }

            case .error:
                Button(action: onDownload) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
```

---

## 9. テスト仕様

### 9.1 ユニットテスト

```swift
final class LanguageManagerTests: XCTestCase {
    var sut: LanguageManager!

    override func setUp() {
        sut = LanguageManager.shared
    }

    func test_availableLanguages_shouldContainPhase1Languages() {
        // Given
        let phase1Codes = ["ja-JP", "en-US", "zh-CN", "ko-KR"]

        // When
        let available = sut.availableLanguages

        // Then
        for code in phase1Codes {
            XCTAssertTrue(available.contains { $0.id == code })
        }
    }

    func test_swapLanguages_shouldSwapSourceAndTarget() {
        // Given
        let japanese = sut.availableLanguages.first { $0.code == "ja" }!
        let english = sut.availableLanguages.first { $0.code == "en" }!
        sut.setLanguagePair(source: japanese, target: english)

        // When
        sut.swapLanguages()

        // Then
        XCTAssertEqual(sut.currentPair.source.code, "en")
        XCTAssertEqual(sut.currentPair.target.code, "ja")
    }
}
```

---

## 10. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
