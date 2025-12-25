import Foundation
import os.log

// MARK: - Performance Monitor

/// Monitors and logs performance metrics for streaming translation
public actor PerformanceMonitor {
    // MARK: - Singleton

    public static let shared = PerformanceMonitor()

    // MARK: - Properties

    private var metrics: [String: PerformanceMetric] = [:]
    private var activeTimers: [String: CFAbsoluteTime] = [:]
    private let logger = Logger(subsystem: "com.livelingo", category: "Performance")

    // Latency thresholds (in seconds)
    private let warningThreshold: Double = 0.5
    private let criticalThreshold: Double = 1.0

    // MARK: - Initialization

    private init() {}

    // MARK: - Timer Methods

    /// Start a timer for a specific operation
    public func startTimer(_ name: String) {
        activeTimers[name] = CFAbsoluteTimeGetCurrent()
    }

    /// Stop a timer and record the duration
    @discardableResult
    public func stopTimer(_ name: String) -> Double? {
        guard let startTime = activeTimers.removeValue(forKey: name) else {
            logger.warning("Timer '\(name)' was not started")
            return nil
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        recordMetric(name: name, value: duration)

        return duration
    }

    // MARK: - Metric Recording

    /// Record a performance metric
    public func recordMetric(name: String, value: Double) {
        if var metric = metrics[name] {
            metric.addSample(value)
            metrics[name] = metric
        } else {
            var metric = PerformanceMetric(name: name)
            metric.addSample(value)
            metrics[name] = metric
        }

        // Log warnings for slow operations
        if value >= criticalThreshold {
            logger.error("⚠️ CRITICAL: \(name) took \(String(format: "%.3f", value))s")
        } else if value >= warningThreshold {
            logger.warning("⚡ SLOW: \(name) took \(String(format: "%.3f", value))s")
        }

        #if DEBUG
        print("[Performance] \(name): \(String(format: "%.3f", value * 1000))ms")
        #endif
    }

    // MARK: - Statistics

    /// Get statistics for a specific metric
    public func getStatistics(for name: String) -> PerformanceStatistics? {
        guard let metric = metrics[name] else { return nil }
        return metric.statistics
    }

    /// Get all metrics
    public func getAllMetrics() -> [String: PerformanceStatistics] {
        var result: [String: PerformanceStatistics] = [:]
        for (name, metric) in metrics {
            result[name] = metric.statistics
        }
        return result
    }

    /// Reset all metrics
    public func reset() {
        metrics.removeAll()
        activeTimers.removeAll()
    }

    /// Print a summary report
    public func printReport() {
        logger.info("=== Performance Report ===")
        print("\n=== LiveLingo Performance Report ===\n")

        let sortedMetrics = metrics.sorted { $0.key < $1.key }

        for (name, metric) in sortedMetrics {
            let stats = metric.statistics
            let status = stats.average >= criticalThreshold ? "🔴" :
                        stats.average >= warningThreshold ? "🟡" : "🟢"

            print("\(status) \(name):")
            print("   Samples: \(stats.sampleCount)")
            print("   Average: \(String(format: "%.2f", stats.average * 1000))ms")
            print("   Min: \(String(format: "%.2f", stats.min * 1000))ms")
            print("   Max: \(String(format: "%.2f", stats.max * 1000))ms")
            print("   P95: \(String(format: "%.2f", stats.p95 * 1000))ms")
            print("")
        }

        print("===================================\n")
    }
}

// MARK: - Performance Metric

/// Stores samples for a performance metric
public struct PerformanceMetric: Sendable {
    public let name: String
    private var samples: [Double] = []
    private let maxSamples: Int = 1000

    public init(name: String) {
        self.name = name
    }

    public mutating func addSample(_ value: Double) {
        samples.append(value)
        // Keep only recent samples to prevent memory growth
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    public var statistics: PerformanceStatistics {
        guard !samples.isEmpty else {
            return PerformanceStatistics(
                sampleCount: 0,
                average: 0,
                min: 0,
                max: 0,
                p50: 0,
                p95: 0,
                p99: 0
            )
        }

        let sorted = samples.sorted()
        let count = sorted.count

        return PerformanceStatistics(
            sampleCount: count,
            average: sorted.reduce(0, +) / Double(count),
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            p50: sorted[Int(Double(count) * 0.5)],
            p95: sorted[min(Int(Double(count) * 0.95), count - 1)],
            p99: sorted[min(Int(Double(count) * 0.99), count - 1)]
        )
    }
}

// MARK: - Performance Statistics

/// Statistical summary of performance metrics
public struct PerformanceStatistics: Sendable {
    public let sampleCount: Int
    public let average: Double
    public let min: Double
    public let max: Double
    public let p50: Double   // Median
    public let p95: Double   // 95th percentile
    public let p99: Double   // 99th percentile
}

// MARK: - Streaming Performance Metrics

/// Predefined metric names for streaming translation
public enum StreamingMetric: String {
    case audioCapture = "audio.capture"
    case audioProcessing = "audio.processing"
    case audioPlayback = "audio.playback"

    case webSocketConnect = "websocket.connect"
    case webSocketSend = "websocket.send"
    case webSocketReceive = "websocket.receive"

    case translationRoundTrip = "translation.roundtrip"
    case translationFirstToken = "translation.first_token"
    case translationComplete = "translation.complete"

    case sttRecognition = "stt.recognition"
    case ttsGeneration = "tts.generation"

    case uiUpdate = "ui.update"
}

// MARK: - Performance Monitor Extensions

extension PerformanceMonitor {
    /// Start a timer with a predefined metric
    public func start(_ metric: StreamingMetric) {
        startTimer(metric.rawValue)
    }

    /// Stop a timer with a predefined metric
    @discardableResult
    public func stop(_ metric: StreamingMetric) -> Double? {
        stopTimer(metric.rawValue)
    }

    /// Record a predefined metric
    public func record(_ metric: StreamingMetric, value: Double) {
        recordMetric(name: metric.rawValue, value: value)
    }

    /// Get statistics for a predefined metric
    public func statistics(for metric: StreamingMetric) -> PerformanceStatistics? {
        getStatistics(for: metric.rawValue)
    }
}

// MARK: - Measure Block

/// Convenience function to measure execution time of a block
public func measurePerformance<T>(
    _ name: String,
    block: () async throws -> T
) async rethrows -> T {
    await PerformanceMonitor.shared.startTimer(name)
    defer {
        Task {
            await PerformanceMonitor.shared.stopTimer(name)
        }
    }
    return try await block()
}

/// Synchronous version
public func measurePerformance<T>(
    _ name: String,
    block: () throws -> T
) rethrows -> T {
    let start = CFAbsoluteTimeGetCurrent()
    defer {
        let duration = CFAbsoluteTimeGetCurrent() - start
        Task {
            await PerformanceMonitor.shared.recordMetric(name: name, value: duration)
        }
    }
    return try block()
}
