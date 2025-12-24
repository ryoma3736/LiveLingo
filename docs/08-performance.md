# LiveLingo - パフォーマンス最適化機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | パフォーマンス最適化機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #9 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. パフォーマンス目標

### 2.1 遅延要件

| 指標 | 目標値 | 最大許容値 | 測定方法 |
|------|--------|-----------|----------|
| STT遅延 | < 300ms | 500ms | 発話終了→テキスト表示 |
| 翻訳遅延 | < 500ms | 800ms | テキスト確定→翻訳完了 |
| TTS遅延 | < 200ms | 300ms | 翻訳完了→音声再生開始 |
| **総合遅延（短文）** | **< 1秒** | 1.5秒 | 発話終了→音声再生開始 |
| **総合遅延（長文）** | **< 3秒** | 4秒 | 発話終了→音声再生完了 |

### 2.2 リソース要件

| 指標 | 目標値 | 最大許容値 |
|------|--------|-----------|
| メモリ使用量（待機時） | < 50MB | 100MB |
| メモリ使用量（通訳中） | < 150MB | 200MB |
| CPU使用率（待機時） | < 5% | 10% |
| CPU使用率（通訳中） | < 40% | 60% |
| バッテリー消費 | < 10%/時 | 15%/時 |
| アプリ起動時間 | < 2秒 | 3秒 |

---

## 3. API遅延比較検証

### 3.1 検証対象

| API | プロバイダー | 種類 |
|-----|-------------|------|
| Google Cloud Speech-to-Text | Google | STT |
| Google Live Speech API | Google | STT (最新) |
| CoeFont API | CoeFont | TTS |
| Apple Speech Framework | Apple | STT |
| Apple AVSpeechSynthesizer | Apple | TTS |

### 3.2 検証シナリオ

```swift
// MARK: - API Benchmark Manager

final class APIBenchmarkManager {
    struct BenchmarkResult {
        let apiName: String
        let averageLatency: TimeInterval
        let p50Latency: TimeInterval
        let p95Latency: TimeInterval
        let p99Latency: TimeInterval
        let successRate: Double
        let sampleCount: Int
    }

    // MARK: - 検証実行

    func runBenchmark(iterations: Int = 100) async -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        // Google Live Speech API
        results.append(await benchmarkGoogleLiveSpeech(iterations: iterations))

        // CoeFont API
        results.append(await benchmarkCoeFontTTS(iterations: iterations))

        // Apple Speech Framework
        results.append(await benchmarkAppleSpeech(iterations: iterations))

        return results
    }

    // MARK: - Google Live Speech API

    private func benchmarkGoogleLiveSpeech(iterations: Int) async -> BenchmarkResult {
        var latencies: [TimeInterval] = []
        var successCount = 0

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()

            do {
                try await googleLiveSpeechClient.transcribe(testAudioData)
                let end = CFAbsoluteTimeGetCurrent()
                latencies.append(end - start)
                successCount += 1
            } catch {
                // エラー記録
            }
        }

        return calculateResult(
            apiName: "Google Live Speech API",
            latencies: latencies,
            successCount: successCount,
            totalCount: iterations
        )
    }

    // MARK: - CoeFont API

    private func benchmarkCoeFontTTS(iterations: Int) async -> BenchmarkResult {
        var latencies: [TimeInterval] = []
        var successCount = 0

        let testText = "こんにちは、今日はいい天気ですね。"

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()

            do {
                try await coefontClient.synthesize(text: testText, coefontID: "test-voice")
                let end = CFAbsoluteTimeGetCurrent()
                latencies.append(end - start)
                successCount += 1
            } catch {
                // エラー記録
            }
        }

        return calculateResult(
            apiName: "CoeFont API",
            latencies: latencies,
            successCount: successCount,
            totalCount: iterations
        )
    }

    // MARK: - 結果計算

    private func calculateResult(
        apiName: String,
        latencies: [TimeInterval],
        successCount: Int,
        totalCount: Int
    ) -> BenchmarkResult {
        let sorted = latencies.sorted()

        return BenchmarkResult(
            apiName: apiName,
            averageLatency: latencies.reduce(0, +) / Double(latencies.count),
            p50Latency: sorted[sorted.count / 2],
            p95Latency: sorted[Int(Double(sorted.count) * 0.95)],
            p99Latency: sorted[Int(Double(sorted.count) * 0.99)],
            successRate: Double(successCount) / Double(totalCount),
            sampleCount: totalCount
        )
    }
}
```

### 3.3 検証レポート出力

```swift
struct BenchmarkReportView: View {
    let results: [APIBenchmarkManager.BenchmarkResult]

    var body: some View {
        List {
            Section("遅延比較（平均）") {
                ForEach(results, id: \.apiName) { result in
                    HStack {
                        Text(result.apiName)
                        Spacer()
                        Text("\(Int(result.averageLatency * 1000))ms")
                            .foregroundColor(latencyColor(result.averageLatency))
                    }
                }
            }

            Section("P95遅延") {
                ForEach(results, id: \.apiName) { result in
                    HStack {
                        Text(result.apiName)
                        Spacer()
                        Text("\(Int(result.p95Latency * 1000))ms")
                    }
                }
            }

            Section("成功率") {
                ForEach(results, id: \.apiName) { result in
                    HStack {
                        Text(result.apiName)
                        Spacer()
                        Text("\(Int(result.successRate * 100))%")
                            .foregroundColor(result.successRate > 0.99 ? .green : .orange)
                    }
                }
            }
        }
        .navigationTitle("API性能比較")
    }

    private func latencyColor(_ latency: TimeInterval) -> Color {
        switch latency {
        case ..<0.3: return .green
        case 0.3..<0.5: return .yellow
        default: return .red
        }
    }
}
```

---

## 4. 遅延最小化技術

### 4.1 音声認識最適化

```swift
// MARK: - Low Latency Speech Configuration

struct LowLatencySTTConfig {
    // バッファサイズ（小さいほど低遅延、CPU負荷増）
    static let bufferSize: AVAudioFrameCount = 512  // 32ms @16kHz

    // 部分結果の有効化
    static let shouldReportPartialResults = true

    // オンデバイス優先
    static let requiresOnDeviceRecognition = false

    // タスクヒント
    static let taskHint: SFSpeechRecognitionTaskHint = .dictation
}

// MARK: - Optimized Speech Recognizer

final class OptimizedSpeechRecognizer {
    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?

    func startLowLatencyRecognition(locale: Locale) throws {
        let recognizer = SFSpeechRecognizer(locale: locale)!
        let request = SFSpeechAudioBufferRecognitionRequest()

        // 低遅延設定
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        // 小さいバッファで頻繁にデータを送信
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: LowLatencySTTConfig.bufferSize,
            format: format
        ) { buffer, _ in
            request.append(buffer)
        }

        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            // 部分結果を即座に処理
            if let result = result {
                self.handlePartialResult(result)
            }
        }
    }

    private func handlePartialResult(_ result: SFSpeechRecognitionResult) {
        // 結果を即座にストリーム出力
    }
}
```

### 4.2 翻訳最適化

```swift
// MARK: - Streaming Translation

final class StreamingTranslator {
    private let waitK: Int = 3  // Wait-k戦略

    // ストリーミング翻訳（入力の一部を待って開始）
    func translateStreaming(
        tokenStream: AsyncStream<String>
    ) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                var buffer: [String] = []

                for await token in tokenStream {
                    buffer.append(token)

                    // k単語蓄積後に翻訳開始
                    if buffer.count >= waitK {
                        let segment = buffer.prefix(waitK).joined(separator: " ")
                        buffer.removeFirst(waitK)

                        let translated = await translateSegment(segment)
                        continuation.yield(translated)
                    }
                }

                // 残りを処理
                if !buffer.isEmpty {
                    let remaining = buffer.joined(separator: " ")
                    let translated = await translateSegment(remaining)
                    continuation.yield(translated)
                }

                continuation.finish()
            }
        }
    }

    private func translateSegment(_ segment: String) async -> String {
        // 実際の翻訳処理
        return segment
    }
}
```

### 4.3 音声合成最適化

```swift
// MARK: - Pre-buffered TTS

final class PreBufferedTTS {
    private var audioQueue: [Data] = []
    private let audioPlayer = AudioPlayerManager()
    private let bufferAheadCount = 2  // 2セグメント先読み

    func speakStreaming(textStream: AsyncStream<String>) async {
        var segmentIndex = 0

        for await text in textStream {
            // バックグラウンドで音声合成
            Task {
                let audioData = try? await synthesize(text)
                if let data = audioData {
                    self.enqueueAudio(data, at: segmentIndex)
                }
            }

            segmentIndex += 1
        }
    }

    private func enqueueAudio(_ data: Data, at index: Int) {
        audioQueue.append(data)

        // バッファに十分なデータがあれば再生開始
        if audioQueue.count >= bufferAheadCount {
            playNext()
        }
    }

    private func playNext() {
        guard !audioQueue.isEmpty else { return }
        let data = audioQueue.removeFirst()
        audioPlayer.play(data)
    }
}
```

---

## 5. メモリ最適化

### 5.1 メモリ管理戦略

```swift
// MARK: - Memory Manager

final class MemoryManager {
    static let shared = MemoryManager()

    private let warningThreshold: Float = 0.75  // 75%で警告
    private let criticalThreshold: Float = 0.92  // 92%で強制解放

    // MARK: - メモリ監視

    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }

        // システムメモリ警告通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    private func checkMemoryPressure() {
        let usage = currentMemoryUsage()

        if usage > criticalThreshold {
            performCriticalCleanup()
        } else if usage > warningThreshold {
            performGradualCleanup()
        }
    }

    private func currentMemoryUsage() -> Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else { return 0 }

        let usedMemory = Float(info.resident_size)
        let totalMemory = Float(ProcessInfo.processInfo.physicalMemory)

        return usedMemory / totalMemory
    }

    // MARK: - クリーンアップ

    @objc private func handleMemoryWarning() {
        performCriticalCleanup()
    }

    private func performGradualCleanup() {
        // キャッシュの古いエントリを削除
        TranslationCache.shared.trimOldEntries(keepPercent: 0.5)

        // 未使用の言語モデルをアンロード
        LanguageModelManager.shared.unloadUnusedModels()
    }

    private func performCriticalCleanup() {
        // 全キャッシュクリア
        TranslationCache.shared.clearAll()

        // オーディオバッファクリア
        AudioBufferPool.shared.releaseAll()

        // 会話履歴を最小限に
        ConversationHistory.shared.keepOnly(last: 5)

        // GC強制実行
        autoreleasepool { }
    }
}
```

### 5.2 オブジェクトプール

```swift
// MARK: - Audio Buffer Pool

final class AudioBufferPool {
    static let shared = AudioBufferPool()

    private var availableBuffers: [AVAudioPCMBuffer] = []
    private let lock = NSLock()
    private let maxPoolSize = 10

    func acquireBuffer(
        format: AVAudioFormat,
        frameCapacity: AVAudioFrameCount
    ) -> AVAudioPCMBuffer {
        lock.lock()
        defer { lock.unlock() }

        // プールから取得を試みる
        if let buffer = availableBuffers.popLast() {
            return buffer
        }

        // 新規作成
        return AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCapacity
        )!
    }

    func releaseBuffer(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }

        if availableBuffers.count < maxPoolSize {
            buffer.frameLength = 0  // リセット
            availableBuffers.append(buffer)
        }
        // それ以外は破棄（ARCに任せる）
    }

    func releaseAll() {
        lock.lock()
        defer { lock.unlock() }
        availableBuffers.removeAll()
    }
}
```

---

## 6. バッテリー最適化

### 6.1 電力消費削減

```swift
// MARK: - Power Optimization

final class PowerOptimizer {
    enum PowerMode {
        case performance    // 最高性能（電力消費大）
        case balanced      // バランス
        case efficient     // 省電力
    }

    var currentMode: PowerMode = .balanced {
        didSet {
            applyPowerSettings()
        }
    }

    private func applyPowerSettings() {
        switch currentMode {
        case .performance:
            setHighPerformanceSettings()
        case .balanced:
            setBalancedSettings()
        case .efficient:
            setEfficientSettings()
        }
    }

    private func setHighPerformanceSettings() {
        // 最小バッファサイズ
        AudioSessionManager.shared.setBufferDuration(0.002)
        // クラウドAPI優先
        TranslationManager.shared.preferCloudTranslation = true
        // 高品質TTS
        TTSManager.shared.voiceQuality = .premium
    }

    private func setBalancedSettings() {
        AudioSessionManager.shared.setBufferDuration(0.005)
        TranslationManager.shared.preferCloudTranslation = true
        TTSManager.shared.voiceQuality = .enhanced
    }

    private func setEfficientSettings() {
        // 大きめのバッファ
        AudioSessionManager.shared.setBufferDuration(0.01)
        // オンデバイス優先
        TranslationManager.shared.preferCloudTranslation = false
        // 標準品質TTS
        TTSManager.shared.voiceQuality = .standard
    }
}

// MARK: - Battery Level Observer

final class BatteryObserver {
    func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func batteryLevelChanged() {
        let level = UIDevice.current.batteryLevel

        if level < 0.2 {
            // 低バッテリー時は省電力モードに
            PowerOptimizer.shared.currentMode = .efficient
        }
    }

    @objc private func batteryStateChanged() {
        let state = UIDevice.current.batteryState

        if state == .charging || state == .full {
            // 充電中は性能優先
            PowerOptimizer.shared.currentMode = .performance
        }
    }
}
```

---

## 7. 計測・分析

### 7.1 パフォーマンス計測

```swift
// MARK: - Performance Metrics

final class PerformanceMetrics {
    static let shared = PerformanceMetrics()

    private var metrics: [String: [TimeInterval]] = [:]
    private let lock = NSLock()

    // MARK: - 計測

    func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let end = CFAbsoluteTimeGetCurrent()

        recordMetric(name: name, duration: end - start)

        return result
    }

    func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let end = CFAbsoluteTimeGetCurrent()

        recordMetric(name: name, duration: end - start)

        return result
    }

    private func recordMetric(name: String, duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        if metrics[name] == nil {
            metrics[name] = []
        }
        metrics[name]?.append(duration)

        // 最大1000サンプル保持
        if metrics[name]!.count > 1000 {
            metrics[name]?.removeFirst()
        }
    }

    // MARK: - レポート

    func getReport() -> PerformanceReport {
        lock.lock()
        defer { lock.unlock() }

        var summaries: [MetricSummary] = []

        for (name, values) in metrics {
            let sorted = values.sorted()
            let summary = MetricSummary(
                name: name,
                count: values.count,
                average: values.reduce(0, +) / Double(values.count),
                p50: sorted[sorted.count / 2],
                p95: sorted[Int(Double(sorted.count) * 0.95)],
                min: sorted.first ?? 0,
                max: sorted.last ?? 0
            )
            summaries.append(summary)
        }

        return PerformanceReport(
            timestamp: Date(),
            metrics: summaries
        )
    }
}

struct PerformanceReport {
    let timestamp: Date
    let metrics: [MetricSummary]
}

struct MetricSummary {
    let name: String
    let count: Int
    let average: TimeInterval
    let p50: TimeInterval
    let p95: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
}
```

### 7.2 分析ダッシュボード

```swift
struct PerformanceDashboardView: View {
    @StateObject private var viewModel = PerformanceDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 総合遅延
                MetricCard(
                    title: "総合遅延",
                    value: "\(Int(viewModel.totalLatency * 1000))ms",
                    target: "< 1000ms",
                    status: viewModel.totalLatency < 1.0 ? .good : .warning
                )

                // STT遅延
                MetricCard(
                    title: "音声認識遅延",
                    value: "\(Int(viewModel.sttLatency * 1000))ms",
                    target: "< 300ms",
                    status: viewModel.sttLatency < 0.3 ? .good : .warning
                )

                // 翻訳遅延
                MetricCard(
                    title: "翻訳遅延",
                    value: "\(Int(viewModel.translationLatency * 1000))ms",
                    target: "< 500ms",
                    status: viewModel.translationLatency < 0.5 ? .good : .warning
                )

                // メモリ使用量
                MetricCard(
                    title: "メモリ使用量",
                    value: "\(viewModel.memoryUsageMB)MB",
                    target: "< 150MB",
                    status: viewModel.memoryUsageMB < 150 ? .good : .warning
                )
            }
            .padding()
        }
        .navigationTitle("パフォーマンス")
    }
}

struct MetricCard: View {
    enum Status {
        case good, warning, critical
    }

    let title: String
    let value: String
    let target: String
    let status: Status

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
            }

            Text("目標: \(target)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.llSurface)
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch status {
        case .good: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}
```

---

## 8. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
