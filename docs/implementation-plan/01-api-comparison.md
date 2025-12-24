# LiveLingo API 比較・精査レポート

> 作成日: 2024-12-24
> 目的: リアルタイム翻訳アプリに最適なAPIの選定

## 1. 比較対象API

### A. Google Gemini Live API
### B. CoeFont API
### C. Apple Native APIs（参考）

---

## 2. Google Gemini Live API

### 2.1 概要
2025年12月12日にGoogleが発表した最新のリアルタイム音声翻訳API。Gemini 2.5ネイティブオーディオモデルを活用。

### 2.2 主要機能

| 機能 | 詳細 |
|------|------|
| リアルタイムSTT | 24言語対応、高精度音声認識 |
| リアルタイム翻訳 | 70言語以上対応、Gemini統合 |
| TTS | 話者のトーン・リズム・ペースを保持 |
| 割り込み対応 | "Barge-in"でユーザーが即座に割り込み可能 |
| マルチモーダル | 音声・テキスト・ビジュアル統合処理 |

### 2.3 動作モード

1. **連続リスニングモード**
   - 複数言語の音声を自動検出
   - 単一のターゲット言語に翻訳

2. **双方向会話モード**
   - 2言語間のリアルタイム翻訳
   - 話者に応じて自動で出力言語切替

### 2.4 料金体系

| 項目 | 価格 |
|------|------|
| 音声入力 | 25トークン/秒 |
| 音声出力 | 25トークン/秒 |
| 動画入力 | 258トークン/秒 |
| セッション開始 | $0.005/セッション |
| アクティブ会話 | $0.025/分 |

※プレビュー期間中は一部無料機能あり

### 2.5 iOS統合

```swift
// Firebase AI Logic SDK (推奨)
// firebase-ios-sdk v12.5.0+
import FirebaseAILogic

// または Pipecat WebSocket
// https://github.com/pipecat-ai/pipecat-client-ios-gemini-live-websocket
```

**注意**: 2025年12月時点
- Android: ベータ版利用可能（米国、メキシコ、インド）
- iOS: **2026年対応予定**

### 2.6 強み
- ✅ エンドツーエンドの音声翻訳パイプライン
- ✅ 自然な翻訳品質（トーン・リズム保持）
- ✅ 低レイテンシ
- ✅ Googleの大規模インフラ

### 2.7 課題
- ⚠️ iOS SDKは2026年まで非公式
- ⚠️ プレビュー版のため本番利用に制限
- ⚠️ セッション同時接続数制限（5-10）

---

## 3. CoeFont API

### 3.1 概要
東京工業大学発のAI音声合成プラットフォーム。10,000種類以上の高品質AI音声を提供。

### 3.2 主要機能

| 機能 | 詳細 |
|------|------|
| TTS | 10,000+種類のAI音声 |
| 多言語TTS | Cross-Lingual TTS対応 |
| ボイスチェンジャー | リアルタイム音声変換 |
| 感情表現 | 喜怒哀楽の音声生成 |
| カスタム音声 | 15分収録で自分の声をAI化 |

### 3.3 料金プラン

| プラン | 月額 | 文字数 | API | 商用 |
|--------|------|--------|-----|------|
| Free | ¥0 | 800文字 | ❌ | ❌ |
| Standard | ¥3,300 | 8万文字 | ❌ | ✅ |
| Plus | ¥55,000 | 100万文字 | ✅ | ✅ |

### 3.4 API仕様

```
# API利用にはPlusプラン必須
エンドポイント: https://api.coefont.cloud/v1/synthesis
認証: API Key (Bearer Token)
形式: REST API
出力: WAV/MP3
```

### 3.5 強み
- ✅ 高品質な日本語音声
- ✅ 声優・キャラクター音声
- ✅ 感情表現が豊か
- ✅ 日本企業（サポート充実）

### 3.6 課題
- ⚠️ **TTSのみ**（STT・翻訳は別途必要）
- ⚠️ API利用に月額55,000円
- ⚠️ 文字数課金（コスト予測困難）

---

## 4. Apple Native APIs（参考）

### 4.1 STT: SFSpeechRecognizer
- 無料、オンデバイス対応
- 日本語含む60+言語
- プライバシー重視

### 4.2 翻訳: Translation Framework (iOS 17.4+)
- 無料、オンデバイス対応
- オフライン翻訳可能
- 限定的な言語ペア

### 4.3 TTS: AVSpeechSynthesizer
- 無料、システム内蔵
- 品質は標準〜Enhanced
- カスタマイズ制限

---

## 5. 比較表

| 項目 | Gemini Live | CoeFont | Apple Native |
|------|-------------|---------|--------------|
| **STT** | ✅ 高精度 | ❌ なし | ✅ 標準 |
| **翻訳** | ✅ 70言語 | ❌ なし | ⚠️ 限定 |
| **TTS** | ✅ 自然 | ✅ 高品質 | ✅ 標準 |
| **日本語品質** | ✅ 良好 | ✅ 最高 | ⚠️ 標準 |
| **オフライン** | ❌ | ❌ | ✅ |
| **iOS SDK** | ⚠️ 2026年 | ✅ REST | ✅ 標準 |
| **月額コスト** | 〜$50推定 | ¥55,000 | ¥0 |

---

## 6. 推奨構成

### 6.1 MVP（最小実装）

```
STT: Apple SFSpeechRecognizer（無料・即利用可能）
翻訳: Apple Translation + OpenAI Fallback
TTS: Apple AVSpeechSynthesizer（無料）
```

**メリット**: コストゼロ、即実装可能
**デメリット**: 翻訳品質・TTS品質に制限

### 6.2 Standard（推奨）

```
STT: Apple SFSpeechRecognizer + Whisper API Fallback
翻訳: OpenAI GPT-4 / Anthropic Claude
TTS: Apple AVSpeechSynthesizer + CoeFont（日本語高品質時）
```

**月額コスト**: 約$50-100（使用量による）

### 6.3 Premium（2026年以降）

```
STT + 翻訳 + TTS: Google Gemini Live API（統合パイプライン）
```

**メリット**: 最高品質、低レイテンシ
**デメリット**: iOS対応は2026年以降

---

## 7. 実装ロードマップ

### Phase 1: MVP (Now)
- Apple Native APIs で基本実装
- 動作検証・UI/UX確立

### Phase 2: Enhancement (Q1 2025)
- OpenAI/Anthropic 翻訳統合
- CoeFont TTS統合（日本語高品質）

### Phase 3: Premium (2026)
- Google Gemini Live API 移行
- エンドツーエンド最適化

---

## 8. 結論

| 用途 | 推奨API |
|------|---------|
| STT（音声認識） | **Apple SFSpeechRecognizer** → Gemini Live (2026) |
| 翻訳 | **OpenAI GPT-4 / Claude** → Gemini Live (2026) |
| TTS（日本語高品質） | **CoeFont Plus** (¥55,000/月) |
| TTS（コスト重視） | **Apple AVSpeechSynthesizer** |
| 統合ソリューション | **Google Gemini Live** (iOS 2026年〜) |

### 最終推奨
現時点（2024年12月）では **ハイブリッド構成** を推奨：
1. Apple Native APIs をベースに実装
2. 翻訳品質向上のため OpenAI/Claude を統合
3. 日本語TTS品質が重要な場合は CoeFont Plus を追加検討
4. 2026年以降、Gemini Live API iOS版リリース時に移行検討

---

## Sources

### Google Gemini Live API
- [Gemini Live API Overview - Google Cloud](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/live-api)
- [Gemini 2.5 Native Audio Updates](https://blog.google/products/gemini/gemini-audio-model-updates/)
- [Google Translate Gets Gemini Boost](https://slator.com/google-translate-gets-major-gemini-boost/)
- [TechCrunch: Google Translate Real-time Translations](https://techcrunch.com/2025/12/12/google-translate-now-lets-you-hear-real-time-translations-in-your-headphones/)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [Firebase AI Logic SDK](https://firebase.google.com/docs/ai-logic/get-started)

### CoeFont
- [CoeFont 特徴・料金解説](https://ai-gallery.jp/tools/coefont/)
- [CoeFont Pricing Plans](https://coefont.cloud/selectPlan/en)
- [CoeFont 商用利用について](https://blue-r.co.jp/blog-coefont-commercial-use/)
- [CoeFont 基本機能と事例](https://ainow.jp/coefont/)

### Google Cloud Speech-to-Text
- [Speech-to-Text Pricing](https://cloud.google.com/speech-to-text/pricing)
- [Deepgram Pricing Comparison 2025](https://deepgram.com/learn/speech-to-text-api-pricing-breakdown-2025)
