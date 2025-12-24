# LiveLingo - UIコンポーネント機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | UIコンポーネント機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #6 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. デザインシステム

### 2.1 デザイン原則

1. **シンプルさ**: 通訳中に邪魔にならないミニマルなUI
2. **アクセシビリティ**: 全ユーザーが使いやすいデザイン
3. **レスポンシブ**: 様々なデバイスサイズに対応
4. **一貫性**: 統一されたコンポーネントとスタイル

### 2.2 アイコンガイドライン

> **重要**: 絵文字アイコンは使用禁止。全てSVGアイコンを使用する。

**使用ライブラリ**:
- SF Symbols（Apple純正）
- カスタムSVGアセット

```swift
// 禁止: 絵文字の使用
// Text("🎤") ← NG

// 推奨: SF Symbolsの使用
Image(systemName: "mic.fill")

// 推奨: カスタムSVGの使用
Image("custom-icon")
    .renderingMode(.template)
```

### 2.3 カラーパレット

```swift
extension Color {
    // Primary Colors
    static let llPrimary = Color("Primary")           // #007AFF
    static let llSecondary = Color("Secondary")       // #5856D6

    // Semantic Colors
    static let llSuccess = Color("Success")           // #34C759
    static let llWarning = Color("Warning")           // #FF9500
    static let llError = Color("Error")               // #FF3B30

    // Background Colors
    static let llBackground = Color("Background")     // システム背景
    static let llSurface = Color("Surface")           // カード背景

    // Text Colors
    static let llTextPrimary = Color("TextPrimary")   // 主要テキスト
    static let llTextSecondary = Color("TextSecondary") // 補助テキスト

    // Speaker Colors
    static let llSpeaker1 = Color("Speaker1")         // #007AFF
    static let llSpeaker2 = Color("Speaker2")         // #FF9500
}
```

### 2.4 タイポグラフィ

```swift
extension Font {
    // Headings
    static let llTitle = Font.system(size: 28, weight: .bold)
    static let llHeadline = Font.system(size: 20, weight: .semibold)

    // Body
    static let llBody = Font.system(size: 17, weight: .regular)
    static let llCaption = Font.system(size: 13, weight: .regular)

    // Transcript
    static let llTranscript = Font.system(size: 22, weight: .medium)
    static let llTranscriptSmall = Font.system(size: 18, weight: .regular)
}
```

---

## 3. 画面構成

### 3.1 画面一覧

| 画面ID | 画面名 | 説明 |
|--------|--------|------|
| SCR-001 | スプラッシュ | アプリ起動画面 |
| SCR-002 | オンボーディング | 初回起動時のチュートリアル |
| SCR-003 | ホーム | メイン画面（通訳開始） |
| SCR-004 | 通訳画面 | リアルタイム通訳表示 |
| SCR-005 | 設定 | アプリ設定 |
| SCR-006 | 言語選択 | 翻訳言語の選択 |
| SCR-007 | 音声選択 | AI音声の選択 |
| SCR-008 | 履歴 | 過去の通訳履歴 |
| SCR-009 | 辞書管理 | 専門用語辞書 |

### 3.2 画面遷移図

```
┌──────────┐
│ スプラッシュ │
└────┬─────┘
     │
     ▼ (初回)        (2回目以降)
┌──────────┐     ┌──────────┐
│オンボーディング│ ──▶ │   ホーム   │
└──────────┘     └────┬─────┘
                      │
     ┌────────────────┼────────────────┐
     ▼                ▼                ▼
┌──────────┐   ┌──────────┐   ┌──────────┐
│ 言語選択  │   │ 通訳画面  │   │   設定   │
└──────────┘   └────┬─────┘   └────┬─────┘
                    │              │
                    ▼              ├──▶ 音声選択
               ┌──────────┐        ├──▶ 履歴
               │ 通訳完了  │        └──▶ 辞書管理
               └──────────┘
```

---

## 4. コンポーネント設計

### 4.1 共通コンポーネント

#### LLButton（カスタムボタン）

```swift
struct LLButton: View {
    enum Style {
        case primary
        case secondary
        case outline
        case text
    }

    let title: LocalizedStringKey
    let icon: String?  // SF Symbol名
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .llPrimary
        case .secondary: return .llSecondary
        case .outline: return .clear
        case .text: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .secondary: return .white
        case .outline, .text: return .llPrimary
        }
    }
}
```

#### LLIconButton（アイコンボタン）

```swift
struct LLIconButton: View {
    let icon: String  // SF Symbol名
    let size: CGFloat
    let action: () -> Void

    init(icon: String, size: CGFloat = 44, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .medium))
                .frame(width: size, height: size)
                .background(Color.llSurface)
                .clipShape(Circle())
        }
    }
}
```

#### LLLanguageToggle（言語切替）

```swift
struct LLLanguageToggle: View {
    @Binding var sourceLanguage: SupportedLanguage
    @Binding var targetLanguage: SupportedLanguage

    var body: some View {
        HStack(spacing: 16) {
            // Source Language
            LanguageSelector(language: $sourceLanguage)

            // Swap Button
            LLIconButton(icon: "arrow.left.arrow.right", size: 40) {
                swap(&sourceLanguage, &targetLanguage)
            }

            // Target Language
            LanguageSelector(language: $targetLanguage)
        }
        .padding()
        .background(Color.llSurface)
        .cornerRadius(16)
    }
}

struct LanguageSelector: View {
    @Binding var language: SupportedLanguage

    var body: some View {
        Menu {
            ForEach(SupportedLanguage.allCases) { lang in
                Button(action: { language = lang }) {
                    HStack {
                        Image(lang.flagIcon)  // SVGフラグアイコン
                        Text(lang.localizedName)
                    }
                }
            }
        } label: {
            HStack {
                Image(language.flagIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(language.code.uppercased())
                    .font(.llBody)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.llBackground)
            .cornerRadius(8)
        }
    }
}
```

---

## 5. 主要画面設計

### 5.1 ホーム画面（SCR-003）

```swift
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var sourceLanguage: SupportedLanguage = .japanese
    @State private var targetLanguage: SupportedLanguage = .english

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo (SVG)
                Image("livelingo-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)

                // Language Toggle
                LLLanguageToggle(
                    sourceLanguage: $sourceLanguage,
                    targetLanguage: $targetLanguage
                )

                // Start Button
                LLButton(
                    title: "start_interpretation",
                    icon: "mic.fill",
                    style: .primary
                ) {
                    viewModel.startInterpretation(
                        source: sourceLanguage,
                        target: targetLanguage
                    )
                }
                .frame(width: 200, height: 200)
                .clipShape(Circle())

                Spacer()

                // Quick Actions
                HStack(spacing: 40) {
                    QuickActionButton(icon: "clock.arrow.circlepath", title: "history") {
                        viewModel.showHistory()
                    }

                    QuickActionButton(icon: "book.closed", title: "dictionary") {
                        viewModel.showDictionary()
                    }

                    QuickActionButton(icon: "gearshape", title: "settings") {
                        viewModel.showSettings()
                    }
                }
            }
            .padding()
            .navigationDestination(for: NavigationPath.self) { path in
                // 画面遷移
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.llCaption)
            }
            .foregroundColor(.llTextSecondary)
        }
    }
}
```

### 5.2 通訳画面（SCR-004）

```swift
struct InterpretationView: View {
    @StateObject private var viewModel: InterpretationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            InterpretationHeader(
                sourceLanguage: viewModel.sourceLanguage,
                targetLanguage: viewModel.targetLanguage,
                onClose: { dismiss() }
            )

            // Transcript Area
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.transcriptItems) { item in
                        TranscriptBubble(item: item)
                    }
                }
                .padding()
            }

            // Live Indicator
            if viewModel.isListening {
                LiveIndicatorView(audioLevel: viewModel.audioLevel)
            }

            // Control Bar
            InterpretationControlBar(
                isListening: viewModel.isListening,
                onToggle: { viewModel.toggleListening() },
                onSwapLanguages: { viewModel.swapLanguages() }
            )
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Transcript Bubble

struct TranscriptBubble: View {
    let item: TranscriptItem

    var body: some View {
        VStack(alignment: item.speaker == .speaker1 ? .leading : .trailing, spacing: 4) {
            // Original Text
            Text(item.originalText)
                .font(.llTranscriptSmall)
                .foregroundColor(.llTextSecondary)

            // Translated Text
            Text(item.translatedText)
                .font(.llTranscript)
                .foregroundColor(.llTextPrimary)
                .padding()
                .background(item.speaker == .speaker1 ? Color.llSpeaker1.opacity(0.1) : Color.llSpeaker2.opacity(0.1))
                .cornerRadius(16)

            // Timestamp
            Text(item.timestamp, style: .time)
                .font(.llCaption)
                .foregroundColor(.llTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: item.speaker == .speaker1 ? .leading : .trailing)
    }
}

// MARK: - Live Indicator

struct LiveIndicatorView: View {
    let audioLevel: Float

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.llPrimary)
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .frame(height: 30)
        .padding()
        .background(Color.llSurface)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(audioLevel)
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 24

        return baseHeight + (maxHeight - baseHeight) * normalizedLevel * (1 - CGFloat(abs(index - 2)) * 0.2)
    }
}

// MARK: - Control Bar

struct InterpretationControlBar: View {
    let isListening: Bool
    let onToggle: () -> Void
    let onSwapLanguages: () -> Void

    var body: some View {
        HStack(spacing: 32) {
            // Swap Languages
            LLIconButton(icon: "arrow.left.arrow.right", size: 50, action: onSwapLanguages)

            // Main Control
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.llError : Color.llPrimary)
                        .frame(width: 80, height: 80)

                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            // Settings
            LLIconButton(icon: "slider.horizontal.3", size: 50) {
                // Show quick settings
            }
        }
        .padding(.vertical, 24)
        .background(Color.llSurface)
    }
}
```

---

## 6. 多言語UI対応

### 6.1 対応言語

| 言語 | コード | ステータス |
|------|--------|----------|
| 日本語 | ja | 必須 |
| 英語 | en | 必須 |
| 中国語（簡体） | zh-Hans | 必須 |

### 6.2 言語切替実装

```swift
// MARK: - App Language Manager

final class AppLanguageManager: ObservableObject {
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set([currentLanguage.code], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    enum AppLanguage: String, CaseIterable, Identifiable {
        case japanese = "ja"
        case english = "en"
        case chinese = "zh-Hans"

        var id: String { rawValue }
        var code: String { rawValue }

        var displayName: String {
            switch self {
            case .japanese: return "日本語"
            case .english: return "English"
            case .chinese: return "中文"
            }
        }

        var flagIcon: String {
            switch self {
            case .japanese: return "flag-jp"
            case .english: return "flag-us"
            case .chinese: return "flag-cn"
            }
        }
    }

    init() {
        let savedLanguage = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "ja"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .japanese
    }
}

// MARK: - Language Switch View

struct LanguageSwitchView: View {
    @EnvironmentObject var languageManager: AppLanguageManager

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguageManager.AppLanguage.allCases) { language in
                Button(action: {
                    withAnimation {
                        languageManager.currentLanguage = language
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(language.flagIcon)  // SVGフラグ
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)

                        Text(language.displayName)
                            .font(.llCaption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        languageManager.currentLanguage == language
                            ? Color.llPrimary.opacity(0.1)
                            : Color.clear
                    )
                }
                .foregroundColor(
                    languageManager.currentLanguage == language
                        ? .llPrimary
                        : .llTextSecondary
                )
            }
        }
        .background(Color.llSurface)
        .cornerRadius(8)
    }
}
```

### 6.3 Localizable.strings

```
// Localizable.strings (Japanese)
"start_interpretation" = "通訳を開始";
"stop_interpretation" = "停止";
"history" = "履歴";
"dictionary" = "辞書";
"settings" = "設定";
"select_language" = "言語を選択";
"swap_languages" = "言語を入れ替え";
"voice_settings" = "音声設定";
"app_language" = "アプリの言語";

// Localizable.strings (English)
"start_interpretation" = "Start Interpretation";
"stop_interpretation" = "Stop";
"history" = "History";
"dictionary" = "Dictionary";
"settings" = "Settings";
"select_language" = "Select Language";
"swap_languages" = "Swap Languages";
"voice_settings" = "Voice Settings";
"app_language" = "App Language";

// Localizable.strings (Chinese Simplified)
"start_interpretation" = "开始翻译";
"stop_interpretation" = "停止";
"history" = "历史";
"dictionary" = "词典";
"settings" = "设置";
"select_language" = "选择语言";
"swap_languages" = "切换语言";
"voice_settings" = "语音设置";
"app_language" = "应用语言";
```

---

## 7. SVGアイコン管理

### 7.1 アイコン一覧

| アイコン名 | ファイル | 用途 |
|-----------|---------|------|
| livelingo-logo | logo.svg | ロゴ |
| flag-jp | flags/jp.svg | 日本国旗 |
| flag-us | flags/us.svg | 米国国旗 |
| flag-cn | flags/cn.svg | 中国国旗 |
| flag-kr | flags/kr.svg | 韓国国旗 |
| flag-fr | flags/fr.svg | フランス国旗 |
| flag-es | flags/es.svg | スペイン国旗 |
| flag-vn | flags/vn.svg | ベトナム国旗 |
| flag-br | flags/br.svg | ブラジル国旗 |

### 7.2 SVGアセット設定

```swift
// Assets.xcassets での設定
// - Render As: Template Image（色変更可能にする場合）
// - Scales: Single Scale
// - Preserve Vector Data: ON

// 使用例
Image("flag-jp")
    .renderingMode(.original)  // オリジナル色を維持
    .resizable()
    .scaledToFit()
    .frame(width: 32, height: 32)
```

---

## 8. アクセシビリティ

### 8.1 VoiceOver対応

```swift
extension View {
    func llAccessibilityLabel(_ label: LocalizedStringKey) -> some View {
        self.accessibilityLabel(label)
    }

    func llAccessibilityHint(_ hint: LocalizedStringKey) -> some View {
        self.accessibilityHint(hint)
    }
}

// 使用例
LLButton(title: "start_interpretation", icon: "mic.fill", style: .primary) {
    // action
}
.llAccessibilityLabel("start_interpretation")
.llAccessibilityHint("accessibility_hint_start_interpretation")
```

### 8.2 Dynamic Type対応

```swift
struct LLText: View {
    let text: LocalizedStringKey
    let style: Font.TextStyle

    @ScaledMetric private var scaleFactor: CGFloat = 1.0

    var body: some View {
        Text(text)
            .font(.system(size: baseSize * scaleFactor, weight: fontWeight))
    }

    private var baseSize: CGFloat {
        switch style {
        case .title: return 28
        case .headline: return 20
        case .body: return 17
        case .caption: return 13
        default: return 17
        }
    }

    private var fontWeight: Font.Weight {
        switch style {
        case .title: return .bold
        case .headline: return .semibold
        default: return .regular
        }
    }
}
```

---

## 9. テスト仕様

### 9.1 UIテスト

```swift
final class HomeViewUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func test_startInterpretation_shouldNavigateToInterpretationView() {
        // Given
        let startButton = app.buttons["start_interpretation"]

        // When
        startButton.tap()

        // Then
        XCTAssertTrue(app.otherElements["interpretation_view"].exists)
    }

    func test_languageSwitch_shouldChangeAppLanguage() {
        // Given
        app.buttons["settings"].tap()
        let englishButton = app.buttons["English"]

        // When
        englishButton.tap()

        // Then
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }

    func test_noEmojis_shouldUseOnlySFSymbols() {
        // アプリ内に絵文字が使われていないことを確認
        let emojiRegex = try! NSRegularExpression(pattern: "[\\p{Emoji}]")
        // UIテストでテキスト要素をチェック
    }
}
```

---

## 10. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
