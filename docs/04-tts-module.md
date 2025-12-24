# LiveLingo - 音声合成（TTS）モジュール機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | TTSモジュール機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #5 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

翻訳されたテキストを自然な音声で再生し、ユーザーに聞きやすい形で通訳結果を伝える。

### 2.2 主要責務

1. テキストから音声への変換
2. 多言語音声合成
3. 音声品質・速度の調整
4. カスタム音声対応（ユーザー声クローン）
5. ストリーミング音声再生

---

## 3. 機能要件

### 3.1 コア機能

#### F-TTS-001: リアルタイム音声合成

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TTS-001 |
| 機能名 | リアルタイム音声合成 |
| 説明 | 翻訳テキストを即座に音声化 |
| 優先度 | P0（必須） |

**入力**:
```swift
struct SpeechSynthesisRequest {
    let text: String                    // 読み上げテキスト
    let language: Locale                // 言語
    let voice: VoiceConfiguration       // 音声設定
    let speed: Float                    // 速度 (0.5-2.0)
    let pitch: Float                    // ピッチ (0.5-2.0)
    let volume: Float                   // 音量 (0.0-1.0)
}

struct VoiceConfiguration {
    let voiceID: String                 // 音声ID
    let quality: VoiceQuality           // 品質
    let type: VoiceType                 // 種類
}

enum VoiceQuality {
    case standard       // 標準（プリインストール）
    case enhanced       // 高品質（ダウンロード必要）
    case premium        // 最高品質
}

enum VoiceType {
    case system         // システム音声
    case coefont        // CoeFont AI音声
    case personal       // Personal Voice
}
```

**受入条件**:
- [ ] テキスト受信から200ms以内に音声再生開始
- [ ] 途切れのないスムーズな再生
- [ ] 8言語全てで自然な発音

#### F-TTS-002: 音声選択

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TTS-002 |
| 機能名 | 音声選択 |
| 説明 | 複数の音声から選択 |
| 優先度 | P0（必須） |

**利用可能音声**:
| 言語 | システム音声 | CoeFont音声 |
|------|-------------|-------------|
| 日本語 | 10+ | 1,000+ |
| 英語 | 20+ | 500+ |
| 中国語 | 5+ | 200+ |
| 韓国語 | 3+ | 100+ |
| フランス語 | 5+ | 50+ |
| スペイン語 | 10+ | 50+ |
| ベトナム語 | 2+ | 30+ |
| ポルトガル語 | 5+ | 30+ |

#### F-TTS-003: Personal Voice対応

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TTS-003 |
| 機能名 | Personal Voice |
| 説明 | ユーザー自身の声で音声合成 |
| 優先度 | P1 |

**要件**:
- iOS 17+
- 約15分の音声録音でトレーニング
- デバイスローカルで処理

```swift
struct PersonalVoiceConfig {
    let isEnabled: Bool
    let voiceID: String?               // Personal Voice ID
    let fallbackVoice: VoiceConfiguration  // フォールバック音声
}
```

#### F-TTS-004: CoeFont AI音声統合

| 項目 | 仕様 |
|------|------|
| 機能ID | F-TTS-004 |
| 機能名 | CoeFont AI音声 |
| 説明 | 10,000+のAI音声を利用 |
| 優先度 | P1 |

**API仕様**:
- エンドポイント: `https://api.coefont.cloud/v2/text2speech`
- 認証: HMAC-SHA256
- レート制限: 100リクエスト/分（トライアル）
- 最大文字数: 1,000文字/リクエスト

---

## 4. 技術設計

### 4.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                       TTS Module                             │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐       │
│  │              SpeechSynthesisManager               │       │
│  │  - リクエスト管理                                 │       │
│  │  - エンジン切替                                   │       │
│  │  - 再生キュー管理                                 │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Apple TTS   │  │ CoeFont     │  │ Custom      │         │
│  │ Synthesizer │  │ API Client  │  │ Voice       │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌──────────────────────────────────────────────────┐       │
│  │              Audio Player Manager                 │       │
│  │  - バッファ管理                                   │       │
│  │  - ストリーミング再生                             │       │
│  │  - 音量/速度制御                                  │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Protocol定義

```swift
// MARK: - Speech Synthesizer Protocol

protocol SpeechSynthesizerProtocol {
    var playbackState: AnyPublisher<PlaybackState, Never> { get }

    func speak(_ request: SpeechSynthesisRequest) async throws
    func speakStreaming(_ textStream: AnyPublisher<String, Never>) async throws
    func pause()
    func resume()
    func stop()
    func setVoice(_ voice: VoiceConfiguration) throws
}

enum PlaybackState {
    case idle
    case preparing
    case playing
    case paused
    case finished
    case error(Error)
}
```

### 4.3 主要クラス実装

```swift
// MARK: - SpeechSynthesisManager

final class SpeechSynthesisManager: SpeechSynthesizerProtocol {
    // 依存関係
    private let appleSynthesizer: AppleSpeechSynthesizer
    private let coefontClient: CoeFontAPIClient?
    private let audioPlayer: AudioPlayerManager

    // 状態
    private let stateSubject = CurrentValueSubject<PlaybackState, Never>(.idle)
    private var currentVoice: VoiceConfiguration
    private var speechQueue: [SpeechSynthesisRequest] = []

    var playbackState: AnyPublisher<PlaybackState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    // MARK: - 初期化

    init(config: TTSConfig) {
        self.appleSynthesizer = AppleSpeechSynthesizer()
        self.coefontClient = config.coefontAPIKey.map { CoeFontAPIClient(apiKey: $0) }
        self.audioPlayer = AudioPlayerManager()
        self.currentVoice = config.defaultVoice
    }

    // MARK: - 音声合成

    func speak(_ request: SpeechSynthesisRequest) async throws {
        stateSubject.send(.preparing)

        switch request.voice.type {
        case .system:
            try await speakWithApple(request)
        case .coefont:
            try await speakWithCoeFont(request)
        case .personal:
            try await speakWithPersonalVoice(request)
        }
    }

    private func speakWithApple(_ request: SpeechSynthesisRequest) async throws {
        let utterance = AVSpeechUtterance(string: request.text)
        utterance.voice = AVSpeechSynthesisVoice(language: request.language.identifier)
        utterance.rate = request.speed * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = request.pitch
        utterance.volume = request.volume

        stateSubject.send(.playing)

        try await withCheckedThrowingContinuation { continuation in
            appleSynthesizer.speak(utterance) { result in
                switch result {
                case .success:
                    self.stateSubject.send(.finished)
                    continuation.resume()
                case .failure(let error):
                    self.stateSubject.send(.error(error))
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

---

## 5. AVSpeechSynthesizer実装詳細

### 5.1 基本実装

```swift
import AVFoundation

final class AppleSpeechSynthesizer: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var completionHandler: ((Result<Void, Error>) -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - 音声合成

    func speak(_ utterance: AVSpeechUtterance, completion: @escaping (Result<Void, Error>) -> Void) {
        self.completionHandler = completion
        synthesizer.speak(utterance)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - 利用可能音声の取得

    func availableVoices(for language: Locale) -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language.identifier.prefix(2).description) }
    }

    func getVoicesByQuality(for language: Locale) -> [VoiceQuality: [AVSpeechSynthesisVoice]] {
        let voices = availableVoices(for: language)
        var result: [VoiceQuality: [AVSpeechSynthesisVoice]] = [:]

        for voice in voices {
            switch voice.quality {
            case .default:
                result[.standard, default: []].append(voice)
            case .enhanced:
                result[.enhanced, default: []].append(voice)
            case .premium:
                result[.premium, default: []].append(voice)
            @unknown default:
                result[.standard, default: []].append(voice)
            }
        }

        return result
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AppleSpeechSynthesizer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completionHandler?(.success(()))
        completionHandler = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        completionHandler?(.failure(TTSError.cancelled))
        completionHandler = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // 進捗通知（必要に応じて）
    }
}
```

### 5.2 音声品質設定

```swift
extension AVSpeechSynthesisVoice {
    static func highQualityVoice(for language: Locale) -> AVSpeechSynthesisVoice? {
        let languageCode = language.identifier

        // Premium > Enhanced > Default の順で検索
        let voices = speechVoices().filter { $0.language.hasPrefix(String(languageCode.prefix(2))) }

        return voices.first { $0.quality == .premium }
            ?? voices.first { $0.quality == .enhanced }
            ?? voices.first
    }
}
```

---

## 6. CoeFont API統合

### 6.1 APIクライアント実装

```swift
import CryptoKit
import Foundation

final class CoeFontAPIClient {
    private let accessKey: String
    private let clientSecret: String
    private let baseURL = URL(string: "https://api.coefont.cloud/v2/")!

    // MARK: - 初期化

    init(accessKey: String, clientSecret: String) {
        self.accessKey = accessKey
        self.clientSecret = clientSecret
    }

    // MARK: - HMAC-SHA256署名生成

    private func generateSignature(timestamp: String, body: Data) -> String {
        let message = timestamp + String(data: body, encoding: .utf8)!
        let key = SymmetricKey(data: Data(clientSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 音声合成リクエスト

    func synthesize(
        text: String,
        coefontID: String,
        speed: Float = 1.0
    ) async throws -> Data {
        let timestamp = String(Int(Date().timeIntervalSince1970))

        let requestBody: [String: Any] = [
            "coefont": coefontID,
            "text": text,
            "speed": speed
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        let signature = generateSignature(timestamp: timestamp, body: bodyData)

        var request = URLRequest(url: baseURL.appendingPathComponent("text2speech"))
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessKey, forHTTPHeaderField: "Authorization")
        request.setValue(timestamp, forHTTPHeaderField: "X-Coefont-Date")
        request.setValue(signature, forHTTPHeaderField: "X-Coefont-Content")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return data  // WAV/MP3 音声データ
        case 401:
            throw TTSError.authenticationFailed
        case 429:
            throw TTSError.rateLimitExceeded
        default:
            throw TTSError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - 利用可能音声の取得

    func getAvailableVoices() async throws -> [CoeFontVoice] {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let bodyData = Data()
        let signature = generateSignature(timestamp: timestamp, body: bodyData)

        var request = URLRequest(url: baseURL.appendingPathComponent("coefonts/pro"))
        request.httpMethod = "GET"
        request.setValue(accessKey, forHTTPHeaderField: "Authorization")
        request.setValue(timestamp, forHTTPHeaderField: "X-Coefont-Date")
        request.setValue(signature, forHTTPHeaderField: "X-Coefont-Content")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([CoeFontVoice].self, from: data)
    }
}

// MARK: - CoeFont Voice Model

struct CoeFontVoice: Codable, Identifiable {
    let id: String
    let name: String
    let language: String
    let gender: String
    let description: String?
    let sampleURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "coefont"
        case name
        case language = "lang"
        case gender
        case description
        case sampleURL = "sample_url"
    }
}
```

### 6.2 CoeFont音声カテゴリ

| カテゴリ | 説明 | 音声数 |
|---------|------|--------|
| Pro Voices | プロ声優による収録音声 | 100+ |
| AI Voices | AIで生成された音声 | 5,000+ |
| User Voices | ユーザー作成音声 | 5,000+ |
| Character Voices | キャラクター音声 | 500+ |

---

## 7. Personal Voice対応（iOS 17+）

### 7.1 Personal Voice取得

```swift
import AVFoundation

final class PersonalVoiceManager {
    // MARK: - Personal Voice確認

    func isPersonalVoiceAvailable() -> Bool {
        guard #available(iOS 17.0, *) else { return false }
        return AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .authorized
    }

    func requestPersonalVoiceAuthorization() async -> Bool {
        guard #available(iOS 17.0, *) else { return false }

        return await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Personal Voice取得

    @available(iOS 17.0, *)
    func getPersonalVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    // MARK: - Personal Voiceで再生

    @available(iOS 17.0, *)
    func speakWithPersonalVoice(text: String) async throws {
        guard let personalVoice = getPersonalVoices().first else {
            throw TTSError.personalVoiceNotAvailable
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = personalVoice

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}
```

---

## 8. ストリーミング再生

### 8.1 Audio Player Manager

```swift
import AVFoundation

final class AudioPlayerManager {
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    // バッファキュー
    private var bufferQueue: [AVAudioPCMBuffer] = []
    private let bufferLock = NSLock()

    // MARK: - ストリーミング再生

    func startStreamingPlayback() throws {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = playerNode else {
            throw TTSError.engineInitializationFailed
        }

        engine.attach(player)

        let format = AVAudioFormat(
            standardFormatWithSampleRate: 24000,
            channels: 1
        )!

        engine.connect(player, to: engine.mainMixerNode, format: format)

        try engine.start()
        player.play()
    }

    func appendAudioData(_ data: Data) throws {
        guard let engine = audioEngine,
              let player = playerNode else {
            throw TTSError.notPlaying
        }

        // データをPCMバッファに変換
        let buffer = try convertToPCMBuffer(data: data)

        bufferLock.lock()
        bufferQueue.append(buffer)
        bufferLock.unlock()

        // バッファをスケジュール
        player.scheduleBuffer(buffer)
    }

    func stopPlayback() {
        playerNode?.stop()
        audioEngine?.stop()

        bufferLock.lock()
        bufferQueue.removeAll()
        bufferLock.unlock()
    }

    private func convertToPCMBuffer(data: Data) throws -> AVAudioPCMBuffer {
        // WAV/MP3データをPCMバッファに変換
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 24000,
            channels: 1
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(data.count / 2)
        ) else {
            throw TTSError.bufferCreationFailed
        }

        // データをコピー
        data.withUnsafeBytes { ptr in
            buffer.floatChannelData?[0].withMemoryRebound(
                to: Int16.self,
                capacity: data.count / 2
            ) { dest in
                _ = memcpy(dest, ptr.baseAddress!, data.count)
            }
        }

        buffer.frameLength = AVAudioFrameCount(data.count / 2)

        return buffer
    }
}
```

---

## 9. 音声設定UI

### 9.1 音声選択ビュー

```swift
struct VoiceSelectionView: View {
    @StateObject private var viewModel: VoiceSelectionViewModel
    @Binding var selectedVoice: VoiceConfiguration

    var body: some View {
        List {
            Section("システム音声") {
                ForEach(viewModel.systemVoices) { voice in
                    VoiceRow(voice: voice, isSelected: selectedVoice.voiceID == voice.id)
                        .onTapGesture {
                            selectedVoice = voice.toConfiguration()
                        }
                }
            }

            Section("CoeFont AI音声") {
                ForEach(viewModel.coefontVoices) { voice in
                    VoiceRow(voice: voice, isSelected: selectedVoice.voiceID == voice.id)
                        .onTapGesture {
                            selectedVoice = voice.toConfiguration()
                        }
                }
            }

            if viewModel.isPersonalVoiceAvailable {
                Section("Personal Voice") {
                    ForEach(viewModel.personalVoices) { voice in
                        VoiceRow(voice: voice, isSelected: selectedVoice.voiceID == voice.id)
                            .onTapGesture {
                                selectedVoice = voice.toConfiguration()
                            }
                    }
                }
            }
        }
        .navigationTitle("音声を選択")
    }
}

struct VoiceRow: View {
    let voice: VoiceInfo
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(voice.name)
                    .font(.headline)
                Text(voice.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }

            Button(action: { /* プレビュー再生 */ }) {
                Image(systemName: "play.circle")
            }
        }
    }
}
```

---

## 10. テスト仕様

### 10.1 ユニットテスト

```swift
final class SpeechSynthesisManagerTests: XCTestCase {
    var sut: SpeechSynthesisManager!

    override func setUp() {
        sut = SpeechSynthesisManager(config: .default)
    }

    func test_speak_shouldStartPlayback() async throws {
        // Given
        let request = SpeechSynthesisRequest(
            text: "Hello, world!",
            language: Locale(identifier: "en-US"),
            voice: .default,
            speed: 1.0,
            pitch: 1.0,
            volume: 1.0
        )

        var states: [PlaybackState] = []
        let cancellable = sut.playbackState
            .sink { states.append($0) }

        // When
        try await sut.speak(request)

        // Then
        XCTAssertTrue(states.contains { if case .playing = $0 { return true }; return false })
        XCTAssertTrue(states.contains { if case .finished = $0 { return true }; return false })
    }

    func test_stop_shouldCancelPlayback() async throws {
        // Given
        let request = SpeechSynthesisRequest(
            text: "This is a long text that will take time to speak",
            language: Locale(identifier: "en-US"),
            voice: .default,
            speed: 1.0,
            pitch: 1.0,
            volume: 1.0
        )

        Task {
            try await sut.speak(request)
        }

        // When
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        sut.stop()

        // Then
        // 再生が停止していることを確認
    }
}
```

### 10.2 パフォーマンステスト

| テスト項目 | 目標値 | 測定方法 |
|-----------|--------|----------|
| 音声合成開始遅延 | < 200ms | リクエストから再生開始まで |
| メモリ使用量 | < 30MB | 再生中の最大メモリ |
| CPU使用率 | < 15% | 再生中の平均CPU |

---

## 11. エラーハンドリング

```swift
enum TTSError: Error, LocalizedError {
    case voiceNotAvailable
    case engineInitializationFailed
    case bufferCreationFailed
    case notPlaying
    case cancelled
    case personalVoiceNotAvailable
    case authenticationFailed
    case rateLimitExceeded
    case apiError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .voiceNotAvailable:
            return "指定された音声は利用できません"
        case .engineInitializationFailed:
            return "オーディオエンジンの初期化に失敗しました"
        case .bufferCreationFailed:
            return "オーディオバッファの作成に失敗しました"
        case .notPlaying:
            return "再生中ではありません"
        case .cancelled:
            return "再生がキャンセルされました"
        case .personalVoiceNotAvailable:
            return "Personal Voiceは利用できません"
        case .authenticationFailed:
            return "API認証に失敗しました"
        case .rateLimitExceeded:
            return "APIレート制限を超過しました"
        case .apiError(let statusCode):
            return "APIエラー: \(statusCode)"
        case .invalidResponse:
            return "無効なレスポンス"
        }
    }
}
```

---

## 12. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
