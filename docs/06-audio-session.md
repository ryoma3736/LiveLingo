# LiveLingo - オーディオセッション管理機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | オーディオセッション管理機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #7 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

音声入力と音声出力を同時に行う同時通訳機能において、AVAudioSessionを適切に管理し、安定した音声処理を実現する。

### 2.2 主要責務

1. オーディオセッションのカテゴリ・モード設定
2. 入出力デバイス管理（マイク、スピーカー、Bluetooth）
3. 割り込み処理（電話、他アプリ）
4. ルート変更の処理
5. バックグラウンド動作の制御

---

## 3. 機能要件

### 3.1 コア機能

#### F-AUD-001: 同時入出力セッション

| 項目 | 仕様 |
|------|------|
| 機能ID | F-AUD-001 |
| 機能名 | 同時入出力セッション |
| 説明 | 録音と再生を同時に行うセッション設定 |
| 優先度 | P0（必須） |

**セッション設定**:
```swift
struct AudioSessionConfiguration {
    let category: AVAudioSession.Category = .playAndRecord
    let mode: AVAudioSession.Mode = .voiceChat
    let options: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker,
        .allowBluetooth,
        .allowBluetoothA2DP,
        .mixWithOthers
    ]
    let preferredSampleRate: Double = 16000.0
    let preferredIOBufferDuration: TimeInterval = 0.005  // 5ms
}
```

#### F-AUD-002: 割り込み処理

| 項目 | 仕様 |
|------|------|
| 機能ID | F-AUD-002 |
| 機能名 | 割り込み処理 |
| 説明 | 電話・他アプリの割り込みを適切に処理 |
| 優先度 | P0（必須） |

**割り込みタイプ**:
| 割り込み | 動作 |
|---------|------|
| 電話着信 | 通訳一時停止、終了後再開 |
| Siri起動 | 通訳一時停止、終了後再開 |
| 他アプリ音声 | ミックス再生（設定による） |
| アラーム | 通訳一時停止 |

#### F-AUD-003: ルート変更処理

| 項目 | 仕様 |
|------|------|
| 機能ID | F-AUD-003 |
| 機能名 | ルート変更処理 |
| 説明 | オーディオデバイス変更を検知・処理 |
| 優先度 | P0（必須） |

**サポートデバイス**:
- 内蔵マイク/スピーカー
- AirPods / Bluetooth ヘッドセット
- 有線イヤホン/ヘッドホン
- CarPlay

---

## 4. 技術設計

### 4.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                  Audio Session Manager                       │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐       │
│  │           AVAudioSession Configuration            │       │
│  │  - Category: playAndRecord                        │       │
│  │  - Mode: voiceChat                                │       │
│  │  - Options: defaultToSpeaker, allowBluetooth     │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Interruption│  │   Route     │  │  Device     │         │
│  │   Handler   │  │  Handler    │  │  Manager    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                 │
│         ▼                ▼                ▼                 │
│  ┌──────────────────────────────────────────────────┐       │
│  │              State Publisher                      │       │
│  │  (Combine: AnyPublisher<AudioSessionState>)      │       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 主要クラス実装

```swift
import AVFoundation
import Combine

// MARK: - Audio Session State

enum AudioSessionState {
    case active
    case inactive
    case interrupted(reason: InterruptionReason)
    case routeChanged(newRoute: AudioRoute)
    case error(Error)
}

enum InterruptionReason {
    case phoneCall
    case siri
    case alarm
    case otherApp
    case unknown
}

struct AudioRoute {
    let inputs: [AVAudioSessionPortDescription]
    let outputs: [AVAudioSessionPortDescription]
    let preferredInput: AVAudioSessionPortDescription?
    let preferredOutput: AVAudioSessionPortDescription?
}

// MARK: - Audio Session Manager

final class AudioSessionManager: ObservableObject {
    // シングルトン
    static let shared = AudioSessionManager()

    // パブリッシャー
    @Published private(set) var state: AudioSessionState = .inactive
    @Published private(set) var currentRoute: AudioRoute?
    @Published private(set) var isInterrupted: Bool = false

    // プライベート
    private let session = AVAudioSession.sharedInstance()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 初期化

    private init() {
        setupNotifications()
    }

    // MARK: - セッション設定

    func configureSession(for config: AudioSessionConfiguration = .default) throws {
        do {
            // カテゴリ設定
            try session.setCategory(
                config.category,
                mode: config.mode,
                options: config.options
            )

            // サンプルレート設定
            try session.setPreferredSampleRate(config.preferredSampleRate)

            // バッファサイズ設定（低遅延）
            try session.setPreferredIOBufferDuration(config.preferredIOBufferDuration)

            print("Audio session configured successfully")
        } catch {
            state = .error(error)
            throw AudioSessionError.configurationFailed(error)
        }
    }

    func activateSession() throws {
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            state = .active
            updateCurrentRoute()
        } catch {
            state = .error(error)
            throw AudioSessionError.activationFailed(error)
        }
    }

    func deactivateSession() throws {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            state = .inactive
        } catch {
            state = .error(error)
            throw AudioSessionError.deactivationFailed(error)
        }
    }

    // MARK: - 通知設定

    private func setupNotifications() {
        // 割り込み通知
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                self?.handleInterruption(notification)
            }
            .store(in: &cancellables)

        // ルート変更通知
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] notification in
                self?.handleRouteChange(notification)
            }
            .store(in: &cancellables)

        // メディアサーバーリセット通知
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                self?.handleMediaServicesReset()
            }
            .store(in: &cancellables)
    }

    // MARK: - 割り込み処理

    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            isInterrupted = true
            let reason = determineInterruptionReason(from: userInfo)
            state = .interrupted(reason: reason)
            NotificationCenter.default.post(name: .audioSessionInterruptionBegan, object: reason)

        case .ended:
            isInterrupted = false
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? activateSession()
                    NotificationCenter.default.post(name: .audioSessionInterruptionEnded, object: true)
                }
            }

        @unknown default:
            break
        }
    }

    private func determineInterruptionReason(from userInfo: [AnyHashable: Any]) -> InterruptionReason {
        if let reasonValue = userInfo[AVAudioSessionInterruptionReasonKey] as? UInt,
           let reason = AVAudioSession.InterruptionReason(rawValue: reasonValue) {
            switch reason {
            case .default:
                return .unknown
            case .appWasSuspended:
                return .otherApp
            case .builtInMicMuted:
                return .siri
            @unknown default:
                return .unknown
            }
        }
        return .unknown
    }

    // MARK: - ルート変更処理

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        updateCurrentRoute()

        switch reason {
        case .newDeviceAvailable:
            // 新しいデバイス接続（Bluetoothなど）
            print("New audio device available")

        case .oldDeviceUnavailable:
            // デバイス切断
            if let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                handleDeviceDisconnection(previousRoute: previousRoute)
            }

        case .categoryChange:
            print("Audio category changed")

        case .override:
            print("Audio route override")

        default:
            break
        }
    }

    private func handleDeviceDisconnection(previousRoute: AVAudioSessionRouteDescription) {
        // イヤホン抜けた場合の処理
        let wasUsingHeadphones = previousRoute.outputs.contains { port in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(port.portType)
        }

        if wasUsingHeadphones {
            // スピーカーに切り替え
            NotificationCenter.default.post(name: .audioRouteHeadphonesDisconnected, object: nil)
        }
    }

    // MARK: - メディアサーバーリセット

    private func handleMediaServicesReset() {
        // 全ての音声処理を再初期化
        try? configureSession()
        try? activateSession()
    }

    // MARK: - ルート更新

    private func updateCurrentRoute() {
        let route = session.currentRoute
        currentRoute = AudioRoute(
            inputs: route.inputs,
            outputs: route.outputs,
            preferredInput: session.preferredInput,
            preferredOutput: nil  // iOS doesn't expose preferred output
        )
        state = .routeChanged(newRoute: currentRoute!)
    }

    // MARK: - デバイス選択

    func selectInputDevice(_ port: AVAudioSessionPortDescription) throws {
        try session.setPreferredInput(port)
    }

    func getAvailableInputs() -> [AVAudioSessionPortDescription] {
        return session.availableInputs ?? []
    }

    func getAvailableOutputs() -> [AVAudioSessionPortDescription] {
        return session.currentRoute.outputs
    }
}
```

### 4.3 設定拡張

```swift
extension AudioSessionConfiguration {
    static let `default` = AudioSessionConfiguration()

    static let lowLatency = AudioSessionConfiguration(
        category: .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth],
        preferredSampleRate: 16000.0,
        preferredIOBufferDuration: 0.002  // 2ms - 最低遅延
    )

    static let highQuality = AudioSessionConfiguration(
        category: .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP],
        preferredSampleRate: 44100.0,
        preferredIOBufferDuration: 0.01  // 10ms - 高品質
    )
}
```

---

## 5. バックグラウンド処理

### 5.1 制限事項

> **重要**: iOSはバックグラウンドでの音声認識を公式にサポートしていない。

**許可される操作**:
- 録音のみ（音声認識は不可）
- 音声再生

**対策**:
1. フォアグラウンドで認識処理を実行
2. バックグラウンド移行時は録音のみ継続
3. フォアグラウンド復帰時に録音データを処理

### 5.2 実装

```swift
// Info.plist に追加
// UIBackgroundModes: audio

final class BackgroundAudioManager {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    func handleAppDidEnterBackground() {
        // 録音は継続、認識は一時停止
        beginBackgroundTask()
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    func handleAppWillEnterForeground() {
        endBackgroundTask()
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
    }
}
```

---

## 6. デバイス管理UI

### 6.1 オーディオデバイス選択

```swift
struct AudioDeviceSelectionView: View {
    @StateObject private var audioManager = AudioSessionManager.shared
    @State private var selectedInput: AVAudioSessionPortDescription?
    @State private var selectedOutput: OutputDevice = .speaker

    enum OutputDevice: String, CaseIterable {
        case speaker = "スピーカー"
        case receiver = "レシーバー"
    }

    var body: some View {
        List {
            Section("入力デバイス") {
                ForEach(audioManager.getAvailableInputs(), id: \.uid) { input in
                    HStack {
                        Image(systemName: iconForPortType(input.portType))
                        Text(input.portName)
                        Spacer()
                        if selectedInput?.uid == input.uid {
                            Image(systemName: "checkmark")
                                .foregroundColor(.llPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedInput = input
                        try? audioManager.selectInputDevice(input)
                    }
                }
            }

            Section("出力デバイス") {
                ForEach(OutputDevice.allCases, id: \.self) { device in
                    HStack {
                        Image(systemName: device == .speaker ? "speaker.wave.3" : "phone")
                        Text(device.rawValue)
                        Spacer()
                        if selectedOutput == device {
                            Image(systemName: "checkmark")
                                .foregroundColor(.llPrimary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedOutput = device
                        setOutputDevice(device)
                    }
                }
            }
        }
        .navigationTitle("オーディオデバイス")
    }

    private func iconForPortType(_ type: AVAudioSession.Port) -> String {
        switch type {
        case .builtInMic:
            return "mic"
        case .headsetMic:
            return "headphones"
        case .bluetoothHFP, .bluetoothLE:
            return "airpodspro"
        default:
            return "waveform"
        }
    }

    private func setOutputDevice(_ device: OutputDevice) {
        let session = AVAudioSession.sharedInstance()
        do {
            switch device {
            case .speaker:
                try session.overrideOutputAudioPort(.speaker)
            case .receiver:
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            print("Failed to set output device: \(error)")
        }
    }
}
```

---

## 7. エラーハンドリング

```swift
enum AudioSessionError: Error, LocalizedError {
    case configurationFailed(Error)
    case activationFailed(Error)
    case deactivationFailed(Error)
    case deviceNotAvailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let error):
            return "オーディオ設定に失敗しました: \(error.localizedDescription)"
        case .activationFailed(let error):
            return "オーディオセッションの開始に失敗しました: \(error.localizedDescription)"
        case .deactivationFailed(let error):
            return "オーディオセッションの終了に失敗しました: \(error.localizedDescription)"
        case .deviceNotAvailable:
            return "オーディオデバイスが利用できません"
        case .permissionDenied:
            return "マイクの使用が許可されていません"
        }
    }
}
```

---

## 8. 通知定義

```swift
extension Notification.Name {
    static let audioSessionInterruptionBegan = Notification.Name("audioSessionInterruptionBegan")
    static let audioSessionInterruptionEnded = Notification.Name("audioSessionInterruptionEnded")
    static let audioRouteHeadphonesDisconnected = Notification.Name("audioRouteHeadphonesDisconnected")
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let appWillEnterForeground = Notification.Name("appWillEnterForeground")
}
```

---

## 9. テスト仕様

### 9.1 ユニットテスト

```swift
final class AudioSessionManagerTests: XCTestCase {
    var sut: AudioSessionManager!

    override func setUp() {
        sut = AudioSessionManager.shared
    }

    func test_configureSession_shouldSucceed() {
        // Given
        let config = AudioSessionConfiguration.default

        // When/Then
        XCTAssertNoThrow(try sut.configureSession(for: config))
    }

    func test_activateSession_shouldChangeStateToActive() throws {
        // Given
        try sut.configureSession()

        // When
        try sut.activateSession()

        // Then
        XCTAssertEqual(sut.state, .active)
    }
}
```

### 9.2 割り込みテスト

| テストケース | 期待動作 |
|-------------|----------|
| 電話着信中 | 通訳一時停止 |
| 電話終了後 | 通訳自動再開 |
| Bluetooth切断 | スピーカーに切替 |
| アプリバックグラウンド | 録音継続、認識停止 |

---

## 10. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
