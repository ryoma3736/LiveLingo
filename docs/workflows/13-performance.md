# LiveLingo - Performance Optimization Workflows

## WF-PERF-001: Memory Pressure Response

Cache eviction and cleanup under memory pressure.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant App as AppDelegate
    participant Mem as MemoryManager
    participant Cache as TranslationCache
    participant Pool as AudioBufferPool
    participant History as ConversationHistory

    System->>App: didReceiveMemoryWarning()
    App->>Mem: handleMemoryWarning()

    Mem->>Mem: currentMemoryUsage()
    Note over Mem: Calculate resident_size / physicalMemory

    alt Usage > 92% (Critical)
        Mem->>Mem: performCriticalCleanup()

        par Aggressive Cleanup
            Mem->>Cache: clearAll()
            Cache->>Cache: removeAll()
            Note over Cache: Clear 1000+ cached translations
            and
            Mem->>Pool: releaseAll()
            Pool->>Pool: availableBuffers.removeAll()
            Note over Pool: Release pre-allocated audio buffers
            and
            Mem->>History: keepOnly(last: 5)
            History->>History: truncate in-memory history
        end

        Mem->>Mem: autoreleasepool { }
        Note over Mem: Force garbage collection

    else Usage > 75% (Warning)
        Mem->>Mem: performGradualCleanup()

        Mem->>Cache: trimOldEntries(keepPercent: 0.5)
        Cache->>Cache: evictLRU(50%)

        Mem->>Pool: releaseExcess()
        Pool->>Pool: keepOnly(maxPoolSize / 2)

    else Usage < 75%
        Note over Mem: No action needed
    end

    Mem-->>App: cleanup complete
```

---

## WF-PERF-002: Power Mode Switching

Battery-based optimization strategy.

```mermaid
sequenceDiagram
    participant System as iOS
    participant Observer as BatteryObserver
    participant Power as PowerOptimizer
    participant Audio as AudioSessionManager
    participant Trans as TranslationManager
    participant TTS as TTSManager

    Observer->>System: startBatteryMonitoring()
    System->>System: UIDevice.isBatteryMonitoringEnabled = true

    loop Monitor Battery
        System->>Observer: batteryLevelDidChange
        Observer->>Observer: checkLevel()

        alt Level < 20%
            Observer->>Power: setMode(.efficient)

            Power->>Audio: setBufferDuration(0.01)
            Note over Audio: Larger buffer = less CPU

            Power->>Trans: preferCloudTranslation = false
            Note over Trans: Use on-device (no network)

            Power->>TTS: voiceQuality = .standard
            Note over TTS: Lower quality = less CPU
        else Level >= 20% and Discharging
            Observer->>Power: setMode(.balanced)

            Power->>Audio: setBufferDuration(0.005)
            Power->>Trans: preferCloudTranslation = true
            Power->>TTS: voiceQuality = .enhanced
        end
    end

    loop Monitor Charging
        System->>Observer: batteryStateDidChange

        alt Charging or Full
            Observer->>Power: setMode(.performance)

            Power->>Audio: setBufferDuration(0.002)
            Note over Audio: Minimum latency

            Power->>Trans: preferCloudTranslation = true
            Power->>TTS: voiceQuality = .premium
        end
    end
```

---

## WF-PERF-003: Audio Buffer Pooling

Object reuse for audio processing.

```mermaid
sequenceDiagram
    participant Engine as AVAudioEngine
    participant Pool as AudioBufferPool
    participant Processor as AudioProcessor
    participant Lock as NSLock

    Note over Pool: Initialize pool with 10 buffers

    Engine->>Pool: acquireBuffer(format, frameCapacity)

    Pool->>Lock: lock()

    alt Pool Has Available Buffer
        Pool->>Pool: buffer = availableBuffers.popLast()
        Pool->>Lock: unlock()
        Pool-->>Engine: existingBuffer
    else Pool Empty
        Pool->>Pool: buffer = AVAudioPCMBuffer(format, capacity)
        Pool->>Lock: unlock()
        Pool-->>Engine: newBuffer
    end

    Engine->>Processor: process(buffer)
    Processor->>Processor: performSTT(buffer)
    Processor-->>Engine: processingComplete

    Engine->>Pool: releaseBuffer(buffer)

    Pool->>Lock: lock()

    alt Pool Not Full (< maxPoolSize)
        Pool->>Pool: buffer.frameLength = 0
        Note over Pool: Reset buffer for reuse
        Pool->>Pool: availableBuffers.append(buffer)
    else Pool Full
        Note over Pool: Let ARC deallocate buffer
    end

    Pool->>Lock: unlock()
```

---

## WF-PERF-004: API Latency Monitoring

Performance metrics collection and analysis.

```mermaid
sequenceDiagram
    participant Client as APIClient
    participant Metrics as PerformanceMetrics
    participant Lock as NSLock
    participant Report as ReportGenerator
    participant UI as PerformanceDashboard

    Client->>Metrics: measureAsync("translation")

    Metrics->>Metrics: start = CFAbsoluteTimeGetCurrent()

    Client->>Client: await translateAPI()
    Client-->>Metrics: result

    Metrics->>Metrics: end = CFAbsoluteTimeGetCurrent()
    Metrics->>Metrics: duration = end - start

    Metrics->>Lock: lock()
    Metrics->>Metrics: recordMetric("translation", duration)

    alt Samples < 1000
        Metrics->>Metrics: metrics["translation"].append(duration)
    else Samples >= 1000
        Metrics->>Metrics: metrics["translation"].removeFirst()
        Metrics->>Metrics: metrics["translation"].append(duration)
    end

    Metrics->>Lock: unlock()

    Note over Metrics: Periodic Report Generation

    Metrics->>Report: getReport()

    Report->>Report: calculateStatistics()
    Note over Report: For each metric:<br/>- Average<br/>- P50, P95, P99<br/>- Min, Max

    Report-->>Metrics: PerformanceReport

    Metrics->>UI: updateDashboard(report)

    UI->>UI: displayMetricCards()
    Note over UI: STT: 280ms (green)<br/>Translation: 450ms (yellow)<br/>TTS: 180ms (green)
```

---

## Latency Optimization Flow

```mermaid
flowchart TD
    subgraph STT[Speech Recognition]
        A1[Audio Buffer: 512 frames]
        A2[Partial Results: ON]
        A3[On-device Recognition]
        A1 --> A4[32ms latency]
    end

    subgraph Translation[Translation Engine]
        B1[Wait-k Strategy: k=3]
        B2[Context Window: 5 turns]
        B3[Cache Hit Rate]
        B1 --> B4[Start early]
    end

    subgraph TTS[Text-to-Speech]
        C1[Pre-buffer: 2 segments]
        C2[Streaming Synthesis]
        C3[Audio Queue]
        C1 --> C4[Seamless playback]
    end

    subgraph Pipeline[Total Pipeline]
        D1[Audio Input]
        D2[STT Processing]
        D3[Translation]
        D4[TTS Synthesis]
        D5[Audio Output]

        D1 --> D2
        D2 --> D3
        D3 --> D4
        D4 --> D5

        D1 -.->|Target: <1s| D5
    end
```

---

## Resource Usage Targets

```mermaid
gantt
    title Resource Usage Targets
    dateFormat X
    axisFormat %s

    section Memory
    Idle Target (50MB)     :a1, 0, 50
    Idle Max (100MB)       :a2, 0, 100
    Active Target (150MB)  :a3, 0, 150
    Active Max (200MB)     :a4, 0, 200

    section CPU
    Idle Target (5%)       :b1, 0, 5
    Idle Max (10%)         :b2, 0, 10
    Active Target (40%)    :b3, 0, 40
    Active Max (60%)       :b4, 0, 60

    section Battery
    Target (10%/hour)      :c1, 0, 10
    Max (15%/hour)         :c2, 0, 15
```

---

## Performance Benchmark Workflow

```mermaid
sequenceDiagram
    participant Test as BenchmarkSuite
    participant STT as SpeechAPI
    participant Trans as TranslationAPI
    participant TTS as TTSAPI
    participant Report as BenchmarkReport

    Test->>Test: loadTestData()
    Note over Test: Audio samples, text samples

    loop 100 iterations
        par Parallel Benchmarks
            Test->>STT: measureLatency(audioSample)
            STT-->>Test: {latency, success}
            and
            Test->>Trans: measureLatency(textSample)
            Trans-->>Test: {latency, success}
            and
            Test->>TTS: measureLatency(textSample)
            TTS-->>Test: {latency, success}
        end

        Test->>Test: recordResults()
    end

    Test->>Report: generateReport()

    Report->>Report: calculatePercentiles()
    Report->>Report: compareWithTargets()

    Report-->>Test: BenchmarkResult
    Note over Report: STT: P95=280ms (PASS)<br/>Translation: P95=520ms (WARN)<br/>TTS: P95=180ms (PASS)
```

---

## Cache Efficiency Monitoring

```mermaid
sequenceDiagram
    participant Request as TranslationRequest
    participant Cache as TranslationCache
    participant Stats as CacheStatistics
    participant Alert as AlertSystem

    Request->>Cache: get(text, source, target)

    Cache->>Stats: recordLookup()

    alt Cache Hit
        Cache-->>Request: cachedTranslation
        Stats->>Stats: incrementHits()
    else Cache Miss
        Cache-->>Request: nil
        Stats->>Stats: incrementMisses()
    end

    Stats->>Stats: calculateHitRate()
    Note over Stats: hitRate = hits / (hits + misses)

    alt Hit Rate < 50%
        Stats->>Alert: lowCacheEfficiency(hitRate)
        Alert->>Alert: logWarning()
        Note over Alert: Consider increasing cache size
    else Hit Rate > 80%
        Note over Stats: Healthy cache performance
    end

    Stats->>Stats: updateRollingAverage()
```

---

## Performance State Diagram

```mermaid
stateDiagram-v2
    [*] --> Optimal

    Optimal --> Degraded: latency > target
    Optimal --> Critical: memory > 92%

    Degraded --> Optimal: latency normalized
    Degraded --> Critical: memory > 92%

    Critical --> Cleanup: trigger cleanup
    Cleanup --> Degraded: cleanup complete
    Cleanup --> Critical: cleanup insufficient

    state Critical {
        [*] --> EvictingCache
        EvictingCache --> ReleasingBuffers
        ReleasingBuffers --> TruncatingHistory
        TruncatingHistory --> [*]
    }

    Degraded --> Optimizing: analyze bottleneck
    Optimizing --> Optimal: optimization applied
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
