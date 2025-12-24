# LiveLingo - 音声認識（STT）モジュール機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | STTモジュール機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #3 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

音声入力をリアルタイムでテキストに変換し、最小遅延で翻訳パイプラインに渡す。

### 2.2 主要責務

1. マイク入力の取得・バッファリング
2. 音声のリアルタイム認識（ストリーミング）
3. 「間」検出による意味区切りの判定
4. 部分結果の即座出力
5. 言語自動検出（オプション）
6. ノイズキャンセリング前処理

---

## 3. 機能要件

### 3.1 コア機能

#### F-STT-001: リアルタイム音声認識

| 項目 | 仕様 |
|------|------|
| 機能ID | F-STT-001 |
| 機能名 | リアルタイム音声認識 |
| 説明 | 音声入力を即座にテキスト化 |
| 優先度 | P0（必須） |

**入力**:
- オーディオバッファ（PCM 16kHz、モノラル）

**出力**:
```swift
struct SpeechRecognitionResult {
    let text: String                    // 認識テキスト
    let isFinal: Bool                   // 確定フラグ
    let confidence: Float               // 信頼度 (0.0-1.0)
    let timestamp: Date                 // タイムスタンプ
    let alternatives: [String]          // 代替候補
    let detectedLanguage: Locale?       // 検出言語
}
```

**受入条件**:
- [ ] 音声認識開始から300ms以内に最初の部分結果が出力される
- [ ] 部分結果は50ms間隔で更新される
- [ ] 認識精度95%以上（標準環境）

#### F-STT-002: 間（ポーズ）検出

| 項目 | 仕様 |
|------|------|
| 機能ID | F-STT-002 |
| 機能名 | 間検出 |
| 説明 | 発話の意味区切りを検出 |
| 優先度 | P0（必須） |

**パラメータ**:
```swift
struct PauseDetectionConfig {
    let shortPauseThreshold: TimeInterval = 0.3   // 短い間（文中）
    let longPauseThreshold: TimeInterval = 0.8    // 長い間（文末）
    let silenceThreshold: Float = -40.0           // 無音判定dB
}
```

**出力**:
```swift
enum PauseType {
    case short      // 意味の区切り（カンマ相当）
    case long       // 文末（ピリオド相当）
    case utteranceEnd  // 発話終了
}
```

#### F-STT-003: 言語自動検出

| 項目 | 仕様 |
|------|------|
| 機能ID | F-STT-003 |
| 機能名 | 言語自動検出 |
| 説明 | 入力音声の言語を自動判定 |
| 優先度 | P1 |

**サポート言語**:
- 日本語、英語、中国語、韓国語（Phase 1）
- フランス語、スペイン語、ベトナム語、ポルトガル語（Phase 2）

**受入条件**:
- [ ] 発話開始から500ms以内に言語を判定
- [ ] 判定精度90%以上

#### F-STT-004: デュアルスピーカー認識

| 項目 | 仕様 |
|------|------|
| 機能ID | F-STT-004 |
| 機能名 | デュアルスピーカー認識 |
| 説明 | 2人の話者を同時認識 |
| 優先度 | P1 |

**出力**:
```swift
struct DualSpeakerResult {
    let speaker1: SpeechRecognitionResult
    let speaker2: SpeechRecognitionResult?
    let activeSpeaker: SpeakerID
}

enum SpeakerID {
    case speaker1
    case speaker2
    case both
}
```

---

## 4. 技術設計

### 4.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                      STT Module                              │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ AudioInput   │──▶│ AudioBuffer  │──▶│ VAD Engine   │      │
│  │ Manager      │  │  Manager     │  │ (間検出)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│         │                                    │               │
│         ▼                                    ▼               │
│  ┌──────────────┐                    ┌──────────────┐       │
│  │ Noise        │                    │ Segmentation │       │
│  │ Cancellation │                    │  Manager     │       │
│  └──────────────┘                    └──────────────┘       │
│         │                                    │               │
│         ▼                                    ▼               │
│  ┌──────────────────────────────────────────────────┐       │
│  │          Speech Recognition Engine               │       │
│  │  ┌─────────────┐    ┌─────────────────────┐     │       │
│  │  │ Apple STT   │ or │ WhisperKit (高精度) │     │       │
│  │  │ (低遅延)    │    │                     │     │       │
│  │  └─────────────┘    └─────────────────────┘     │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│                          ▼                                   │
│              ┌──────────────────────┐                       │
│              │  Result Publisher    │                       │
│              │  (Combine Stream)    │                       │
│              └──────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 クラス設計

```swift
// MARK: - Protocol定義

protocol SpeechRecognizerProtocol {
    var recognitionStream: AnyPublisher<SpeechRecognitionResult, Error> { get }
    var pauseStream: AnyPublisher<PauseType, Never> { get }

    func startRecognition(locale: Locale) async throws
    func stopRecognition() async
    func setRecognitionConfig(_ config: RecognitionConfig)
}

protocol AudioInputManagerProtocol {
    var audioBufferStream: AnyPublisher<AVAudioPCMBuffer, Error> { get }

    func startCapture() async throws
    func stopCapture() async
    func setBufferSize(_ size: AVAudioFrameCount)
}

// MARK: - 主要クラス

final class SpeechRecognitionManager: SpeechRecognizerProtocol {
    // 依存関係
    private let audioInputManager: AudioInputManagerProtocol
    private let pauseDetector: PauseDetectorProtocol
    private let speechRecognizer: SFSpeechRecognizer
    private let recognitionRequest: SFSpeechAudioBufferRecognitionRequest

    // 設定
    private var config: RecognitionConfig

    // 状態
    private var recognitionTask: SFSpeechRecognitionTask?
    private let resultSubject = PassthroughSubject<SpeechRecognitionResult, Error>()

    var recognitionStream: AnyPublisher<SpeechRecognitionResult, Error> {
        resultSubject.eraseToAnyPublisher()
    }

    // 実装...
}
```

### 4.3 設定パラメータ

```swift
struct RecognitionConfig {
    // オーディオ設定
    let sampleRate: Double = 16000.0
    let bufferSize: AVAudioFrameCount = 512  // 低遅延用
    let channels: AVAudioChannelCount = 1

    // 認識設定
    let shouldReportPartialResults: Bool = true
    let requiresOnDeviceRecognition: Bool = false  // オフライン
    let contextualStrings: [String] = []  // 専門用語

    // 間検出設定
    let pauseDetection: PauseDetectionConfig

    // 言語設定
    let primaryLocale: Locale
    let autoDetectLanguage: Bool = false
}
```

---

## 5. Apple SFSpeechRecognizer実装詳細

### 5.1 基本実装

```swift
import Speech
import AVFoundation
import Combine

final class AppleSpeechRecognizer {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    private let resultSubject = PassthroughSubject<SpeechRecognitionResult, Error>()
    private let pauseSubject = PassthroughSubject<PauseType, Never>()

    private var lastSpeechTime: Date = Date()
    private var pauseTimer: Timer?

    // MARK: - 初期化

    init(locale: Locale = Locale(identifier: "ja-JP")) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        setupAudioSession()
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? audioSession.setActive(true)
    }

    // MARK: - 認識開始

    func startRecognition() throws {
        // 既存のタスクをキャンセル
        recognitionTask?.cancel()
        recognitionTask = nil

        // リクエスト作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        // 設定
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        // オーディオ入力設定
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 低遅延バッファ設定
        inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.detectPause(buffer: buffer)
        }

        // エンジン開始
        audioEngine.prepare()
        try audioEngine.start()

        // 認識タスク開始
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result: result, error: error)
        }

        // 間検出タイマー開始
        startPauseDetectionTimer()
    }

    // MARK: - 結果処理

    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            resultSubject.send(completion: .failure(error))
            return
        }

        guard let result = result else { return }

        lastSpeechTime = Date()

        let recognitionResult = SpeechRecognitionResult(
            text: result.bestTranscription.formattedString,
            isFinal: result.isFinal,
            confidence: result.bestTranscription.segments.last?.confidence ?? 0,
            timestamp: Date(),
            alternatives: result.transcriptions.dropFirst().map { $0.formattedString },
            detectedLanguage: nil
        )

        resultSubject.send(recognitionResult)
    }

    // MARK: - 間検出

    private func detectPause(buffer: AVAudioPCMBuffer) {
        // RMSレベル計算
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(rms)

        // 無音判定
        if db < -40 {
            // 無音検出 - タイマーで間を判定
        } else {
            lastSpeechTime = Date()
        }
    }

    private func startPauseDetectionTimer() {
        pauseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkPause()
        }
    }

    private func checkPause() {
        let silenceDuration = Date().timeIntervalSince(lastSpeechTime)

        if silenceDuration > 0.8 {
            pauseSubject.send(.long)
        } else if silenceDuration > 0.3 {
            pauseSubject.send(.short)
        }
    }

    // MARK: - 停止

    func stopRecognition() {
        pauseTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}
```

### 5.2 制限事項と対策

| 制限 | 内容 | 対策 |
|------|------|------|
| 時間制限 | 1リクエスト最大60秒 | 自動リスタート機構 |
| レート制限 | 1時間1000リクエスト/デバイス | リクエスト管理 |
| バックグラウンド | 非対応 | 録音のみBG、認識はFG |
| オフライン | 一部言語のみ | WhisperKitフォールバック |

---

## 6. WhisperKit統合（高精度オプション）

### 6.1 実装

```swift
import WhisperKit

final class WhisperSpeechRecognizer {
    private var whisperKit: WhisperKit?
    private let resultSubject = PassthroughSubject<SpeechRecognitionResult, Error>()

    // MARK: - 初期化

    init(modelSize: WhisperModelSize = .base) async throws {
        let config = WhisperKitConfig(model: modelSize.rawValue)
        self.whisperKit = try await WhisperKit(config)
    }

    // MARK: - 認識

    func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> SpeechRecognitionResult {
        guard let whisperKit = whisperKit else {
            throw SpeechError.notInitialized
        }

        // バッファをファイルに書き出し（WhisperKitの要件）
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.wav")
        try writeBuffer(audioBuffer, to: tempURL)

        // 認識実行
        let result = try await whisperKit.transcribe(audioPath: tempURL.path)

        // クリーンアップ
        try? FileManager.default.removeItem(at: tempURL)

        return SpeechRecognitionResult(
            text: result?.text ?? "",
            isFinal: true,
            confidence: 0.9,
            timestamp: Date(),
            alternatives: [],
            detectedLanguage: result?.language.map { Locale(identifier: $0) }
        )
    }
}

enum WhisperModelSize: String {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large-v3"
}
```

---

## 7. テスト仕様

### 7.1 ユニットテスト

```swift
final class SpeechRecognitionManagerTests: XCTestCase {
    var sut: SpeechRecognitionManager!
    var mockAudioInput: MockAudioInputManager!

    override func setUp() {
        mockAudioInput = MockAudioInputManager()
        sut = SpeechRecognitionManager(audioInputManager: mockAudioInput)
    }

    func test_startRecognition_shouldEmitPartialResults() async throws {
        // Given
        let expectation = expectation(description: "Partial result received")
        var receivedResults: [SpeechRecognitionResult] = []

        let cancellable = sut.recognitionStream
            .sink(receiveCompletion: { _ in },
                  receiveValue: { result in
                receivedResults.append(result)
                if !result.isFinal {
                    expectation.fulfill()
                }
            })

        // When
        try await sut.startRecognition(locale: Locale(identifier: "ja-JP"))
        mockAudioInput.simulateAudioInput(text: "テスト")

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertFalse(receivedResults.isEmpty)
    }

    func test_pauseDetection_shouldEmitLongPauseAfter800ms() async throws {
        // Given
        let expectation = expectation(description: "Long pause detected")

        let cancellable = sut.pauseStream
            .filter { $0 == .long }
            .sink { _ in expectation.fulfill() }

        // When
        try await sut.startRecognition(locale: Locale(identifier: "ja-JP"))
        mockAudioInput.simulateSilence(duration: 1.0)

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
```

### 7.2 パフォーマンステスト

| テスト項目 | 目標値 | 測定方法 |
|-----------|--------|----------|
| 初回認識遅延 | < 300ms | 発話開始から最初の部分結果まで |
| 更新間隔 | < 100ms | 部分結果間の時間差 |
| メモリ使用量 | < 50MB | 認識中の最大メモリ |
| CPU使用率 | < 30% | 認識中の平均CPU |

---

## 8. エラーハンドリング

### 8.1 エラー定義

```swift
enum SpeechError: Error, LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case requestCreationFailed
    case recognitionFailed(underlying: Error)
    case audioSessionFailed
    case languageNotSupported(Locale)
    case networkUnavailable
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "音声認識の権限がありません"
        case .recognizerNotAvailable:
            return "音声認識が利用できません"
        case .requestCreationFailed:
            return "認識リクエストの作成に失敗しました"
        case .recognitionFailed(let error):
            return "認識に失敗しました: \(error.localizedDescription)"
        case .audioSessionFailed:
            return "オーディオセッションの設定に失敗しました"
        case .languageNotSupported(let locale):
            return "\(locale.identifier)は対応していません"
        case .networkUnavailable:
            return "ネットワーク接続がありません"
        case .quotaExceeded:
            return "認識クォータを超過しました"
        }
    }
}
```

### 8.2 リカバリー戦略

| エラー | リカバリー方法 |
|--------|---------------|
| quotaExceeded | WhisperKitにフォールバック |
| networkUnavailable | オンデバイス認識に切替 |
| recognizerNotAvailable | 再初期化を試行 |
| audioSessionFailed | セッション再設定 |

---

## 9. 権限管理

### 9.1 必要な権限

| 権限 | Info.plist Key | 説明 |
|------|---------------|------|
| マイク | NSMicrophoneUsageDescription | 音声入力のため |
| 音声認識 | NSSpeechRecognitionUsageDescription | 音声認識のため |

### 9.2 権限チェック実装

```swift
final class SpeechPermissionManager {
    func requestPermissions() async throws -> Bool {
        // マイク権限
        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else {
            throw SpeechError.notAuthorized
        }

        // 音声認識権限
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw SpeechError.notAuthorized
        }

        return true
    }

    func checkPermissions() -> (microphone: Bool, speechRecognition: Bool) {
        let micStatus = AVAudioSession.sharedInstance().recordPermission == .granted
        let speechStatus = SFSpeechRecognizer.authorizationStatus() == .authorized
        return (micStatus, speechStatus)
    }
}
```

---

## 10. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
