# LiveLingo - 単体テスト設計書インデックス

## 概要

本ドキュメントは、LiveLingoプロジェクトの80+データフロー図に基づいて抽出された単体テスト設計書のインデックスです。

**生成日**: 2024-12-24
**対象データフロー**: 80+ diagrams across 8 categories
**テストケース総数**: 500+ test cases

---

## テスト設計書一覧

| No. | ファイル名 | カテゴリ | データフロー数 | テストケース数 |
|-----|------------|----------|----------------|----------------|
| 01 | [01-core-pipeline-tests.md](./01-core-pipeline-tests.md) | コアパイプライン | 12 | 85+ |
| 02 | [02-stt-tests.md](./02-stt-tests.md) | 音声認識 (STT) | 10 | 72+ |
| 03 | [03-translation-tests.md](./03-translation-tests.md) | 翻訳エンジン | 10 | 68+ |
| 04 | [04-tts-tests.md](./04-tts-tests.md) | 音声合成 (TTS) | 8 | 54+ |
| 05 | [05-api-tests.md](./05-api-tests.md) | 外部API連携 | 10 | 65+ |
| 06 | [06-persistence-tests.md](./06-persistence-tests.md) | 永続化・データ管理 | 10 | 62+ |
| 07 | [07-security-tests.md](./07-security-tests.md) | セキュリティ | 10 | 58+ |
| 08 | [08-state-tests.md](./08-state-tests.md) | 状態管理 | 10 | 56+ |

---

## テストケース分類体系

### 1. テストタイプ (Test Types)

| タイプ | コード | 説明 |
|--------|--------|------|
| 正常系 | `P` (Positive) | 期待通りの入力・動作 |
| 異常系 | `N` (Negative) | エラー条件・例外 |
| 境界値 | `B` (Boundary) | 限界値・境界条件 |
| 状態遷移 | `S` (State) | 状態変化テスト |
| 性能 | `F` (Performance) | 速度・メモリ・負荷 |
| セキュリティ | `X` (Security) | 脆弱性・認証・暗号化 |

### 2. 優先度 (Priority)

| 優先度 | レベル | 説明 |
|--------|--------|------|
| P0 | Critical | 基本機能、必須テスト |
| P1 | High | 重要機能、リリース必須 |
| P2 | Medium | 標準機能、推奨テスト |
| P3 | Low | エッジケース、nice-to-have |

### 3. テストID形式

```
TC-{Category}-{DataFlow}-{TestType}{Number}

例: TC-STT-001-P01
    - TC: Test Case
    - STT: カテゴリ（音声認識）
    - 001: データフロー番号
    - P01: 正常系テスト #01
```

---

## カテゴリ別概要

### 01. コアパイプライン (Core Pipeline)

音声入力から翻訳結果出力までのEnd-to-End処理フロー

**対象データフロー:**
- DF-CORE-001: End-to-End Speech Flow
- DF-CORE-002: Wait-k Streaming Pipeline
- DF-CORE-003: Dual Speaker Pipeline
- DF-CORE-004: Pause Detection Flow
- DF-CORE-005: Interruption Handling
- DF-CORE-006: Mode Switching Flow
- DF-CORE-007: Audio Routing Flow
- DF-CORE-008: Pipeline State Machine
- DF-CORE-009: Error Propagation Flow
- DF-CORE-010: Resource Cleanup Flow
- DF-CORE-011: Cold Start Optimization
- DF-CORE-012: Hot Reload Flow

### 02. 音声認識 (STT)

SFSpeechRecognizer/WhisperKitによる音声認識処理

**対象データフロー:**
- DF-STT-001: SFSpeechRecognizer Initialization
- DF-STT-002: Real-time Audio Processing
- DF-STT-003: Partial Result Processing
- DF-STT-004: Final Result Processing
- DF-STT-005: Voice Activity Detection (VAD)
- DF-STT-006: Speaker Diarization
- DF-STT-007: WhisperKit Fallback
- DF-STT-008: Language Auto-Detection
- DF-STT-009: Recognition Error Recovery
- DF-STT-010: Recognition Request Lifecycle

### 03. 翻訳エンジン (Translation)

Apple/OpenAI/Anthropicによる多言語翻訳処理

**対象データフロー:**
- DF-TRN-001: Provider Selection
- DF-TRN-002: Apple Translation On-Device
- DF-TRN-003: OpenAI GPT Translation
- DF-TRN-004: Anthropic Claude Translation
- DF-TRN-005: Context-Aware Translation
- DF-TRN-006: Glossary Application
- DF-TRN-007: Translation Cache
- DF-TRN-008: Wait-k Streaming
- DF-TRN-009: Translation Error Recovery
- DF-TRN-010: Quality Evaluation

### 04. 音声合成 (TTS)

AVSpeechSynthesizer/CoeFont/PersonalVoiceによる音声合成

**対象データフロー:**
- DF-TTS-001: TTS Provider Selection
- DF-TTS-002: AVSpeechSynthesizer Flow
- DF-TTS-003: CoeFont API Synthesis
- DF-TTS-004: Personal Voice (iOS 17+)
- DF-TTS-005: Streaming Audio Queue
- DF-TTS-006: Voice Configuration
- DF-TTS-007: Audio Session Configuration
- DF-TTS-008: TTS Error Recovery

### 05. 外部API連携 (API)

HMAC認証・リトライ・レート制限・証明書ピンニング

**対象データフロー:**
- DF-API-001: CoeFont HMAC-SHA256 Auth
- DF-API-002: Exponential Backoff Retry
- DF-API-003: Rate Limiter (Token Bucket)
- DF-API-004: Network Reachability Monitor
- DF-API-005: Request/Response Logging
- DF-API-006: Certificate Pinning
- DF-API-007: OpenAI API Integration
- DF-API-008: Anthropic API Integration
- DF-API-009: Error Response Handling
- DF-API-010: Timeout Handling

### 06. 永続化・データ管理 (Persistence)

SwiftData CRUD・iCloud同期・キャッシュ管理

**対象データフロー:**
- DF-PER-001: Conversation Save/Load
- DF-PER-002: Full-Text Search
- DF-PER-003: Export Flow
- DF-PER-004: Delete Flow
- DF-PER-005: iCloud Sync
- DF-PER-006: Cache Management
- DF-PER-007: Settings Persistence
- DF-PER-008: Schema Migration
- DF-PER-009: Glossary Management
- DF-PER-010: Backup/Restore

### 07. セキュリティ (Security)

認証・暗号化・Keychain・権限管理

**対象データフロー:**
- DF-SEC-001: Sign in with Apple
- DF-SEC-002: Biometric Auth (Face ID/Touch ID)
- DF-SEC-003: AES-256-GCM Encryption
- DF-SEC-004: AES-256-GCM Decryption
- DF-SEC-005: Keychain Storage
- DF-SEC-006: Permission Request
- DF-SEC-007: Session Token Management
- DF-SEC-008: Secure Network Request
- DF-SEC-009: Security Audit Logging
- DF-SEC-010: Data Privacy Compliance

### 08. 状態管理 (State Management)

アプリライフサイクル・通訳状態・認証状態管理

**対象データフロー:**
- DF-STA-001: Application Lifecycle
- DF-STA-002: Interpretation State Machine
- DF-STA-003: Audio Session State
- DF-STA-004: Authentication State
- DF-STA-005: Network State
- DF-STA-006: Language Selection State
- DF-STA-007: Memory Management State
- DF-STA-008: Navigation State
- DF-STA-009: Translation State
- DF-STA-010: Combined State Overview

---

## テスト実行ガイドライン

### 1. テスト環境要件

```yaml
Platform:
  - iOS 17.0+
  - macOS 14.0+

Simulators:
  - iPhone 15 Pro (iOS 17.0)
  - iPhone 14 (iOS 17.0)
  - iPad Pro 12.9-inch (iOS 17.0)

Hardware Testing:
  - Face ID対応デバイス
  - Touch ID対応デバイス
  - Bluetooth対応デバイス
```

### 2. テスト実行順序

```
1. Unit Tests (単体テスト)
   └── 各コンポーネント独立テスト

2. Integration Tests (結合テスト)
   └── コンポーネント間連携テスト

3. E2E Tests (End-to-Endテスト)
   └── 完全フロー通しテスト

4. Performance Tests (性能テスト)
   └── 負荷・速度・メモリテスト

5. Security Tests (セキュリティテスト)
   └── 脆弱性・認証テスト
```

### 3. カバレッジ目標

| カテゴリ | 目標カバレッジ |
|----------|---------------|
| コアパイプライン | 90%+ |
| 音声認識 (STT) | 85%+ |
| 翻訳エンジン | 85%+ |
| 音声合成 (TTS) | 85%+ |
| 外部API連携 | 80%+ |
| 永続化 | 85%+ |
| セキュリティ | 95%+ |
| 状態管理 | 90%+ |

---

## 関連ドキュメント

- [データフロー図インデックス](../dataflows/00-dataflow-index.md)
- [アーキテクチャ設計書](../architecture/ARCHITECTURE.md)
- [API仕様書](../api/API-SPEC.md)

---

## バージョン履歴

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | 初版作成 - 80+ データフローから500+ テストケース抽出 | AI Agent |
