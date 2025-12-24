# IT-PERF: Performance Integration Tests

## Overview

This document defines integration tests for performance optimization based on workflows WF-PERF-001 through WF-PERF-004. These tests verify memory management, power efficiency, and latency optimization.

**Priority**: P1-High
**Total Test Cases**: 35
**Estimated Execution Time**: 25 minutes

---

## Test Environment

### Required Components
- `MemoryManager`
- `PowerOptimizer`
- `AudioBufferPool`
- `PerformanceMetrics`
- `TranslationCache`

### Mock Dependencies
- `MockMemoryPressureNotification`
- `MockBatteryMonitor`

### Measurement Tools
- XCTest performance metrics
- Instruments integration
- Custom metric collectors

---

## WF-PERF-001: Memory Pressure Response

### Test Case IT-PERF-001-01: Memory Warning Level 1 Response

**Objective**: Verify gradual cleanup at warning level.

**Preconditions**:
- Memory usage at 75%
- Caches populated

**Test Steps**:
1. Fill caches to substantial size
2. Trigger memory warning
3. Measure cleanup

**Expected Results**:
- [ ] 50% cache eviction (LRU)
- [ ] Audio buffer pool trimmed
- [ ] Memory drops below 75%
- [ ] App remains functional

```swift
func testMemoryWarningLevel1() async throws {
    let memoryManager = MemoryManager.shared

    // Fill caches
    memoryManager.translationCache.fill(count: 1000)
    let initialCount = memoryManager.translationCache.count

    // Trigger warning
    NotificationCenter.default.post(
        name: UIApplication.didReceiveMemoryWarningNotification,
        object: nil
    )

    try await Task.sleep(nanoseconds: 500_000_000)

    let finalCount = memoryManager.translationCache.count
    XCTAssertLessThan(finalCount, initialCount / 2 + 100) // ~50% reduction
}
```

---

### Test Case IT-PERF-001-02: Critical Memory (92%) Response

**Objective**: Verify aggressive cleanup at critical level.

**Test Steps**:
1. Push memory to 92%
2. Trigger critical warning
3. Verify aggressive cleanup

**Expected Results**:
- [ ] All caches cleared
- [ ] Audio buffers released
- [ ] History truncated to last 5
- [ ] Memory significantly reduced

```swift
func testCriticalMemoryCleanup() async throws {
    let memoryManager = MemoryManager.shared

    // Simulate critical state
    memoryManager.fillToLevel(0.92)

    memoryManager.performCriticalCleanup()

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(memoryManager.translationCache.count, 0)
    XCTAssertEqual(memoryManager.audioBufferPool.available, 0)
    XCTAssertLessThanOrEqual(memoryManager.conversationHistory.count, 5)
}
```

---

### Test Case IT-PERF-001-03: Autoreleasepool Force Cleanup

**Objective**: Verify autoreleasepool drains correctly.

**Test Steps**:
1. Allocate temporary objects
2. Trigger cleanup
3. Verify deallocation

**Expected Results**:
- [ ] Autoreleased objects freed
- [ ] Memory footprint reduced
- [ ] No leaks
- [ ] Garbage collected

---

### Test Case IT-PERF-001-04: Memory Baseline After Cleanup

**Objective**: Verify memory returns to baseline.

**Test Steps**:
1. Record baseline memory
2. Run memory-intensive operation
3. Trigger cleanup
4. Compare to baseline

**Expected Results**:
- [ ] Baseline: ~50MB idle
- [ ] Peak: may reach 200MB
- [ ] After cleanup: within 20% of baseline
- [ ] No memory growth over time

---

### Test Case IT-PERF-001-05: Cleanup Performance

**Objective**: Verify cleanup doesn't cause UI freeze.

**Test Steps**:
1. Trigger cleanup during UI interaction
2. Measure UI responsiveness

**Expected Results**:
- [ ] No frame drops during cleanup
- [ ] Cleanup < 100ms
- [ ] Background thread used
- [ ] Main thread responsive

---

## WF-PERF-002: Power Mode Switching

### Test Case IT-PERF-002-01: Low Battery Mode Activation

**Objective**: Verify efficient mode at low battery.

**Test Steps**:
1. Battery level drops to 15%
2. Verify power optimizations applied

**Expected Results**:
- [ ] Audio buffer duration increased (lower CPU)
- [ ] Cloud translation disabled (prefer offline)
- [ ] TTS quality reduced to standard
- [ ] User notified of changes

```swift
func testLowBatteryMode() async throws {
    let powerOptimizer = PowerOptimizer.shared

    powerOptimizer.simulateBatteryLevel(0.15)

    XCTAssertEqual(powerOptimizer.currentMode, .efficient)
    XCTAssertFalse(powerOptimizer.preferCloudTranslation)
    XCTAssertEqual(powerOptimizer.ttsQuality, .standard)
}
```

---

### Test Case IT-PERF-002-02: Charging Mode Performance

**Objective**: Verify performance mode when charging.

**Test Steps**:
1. Connect charger
2. Verify high performance settings

**Expected Results**:
- [ ] Audio buffer minimized (low latency)
- [ ] Cloud translation enabled
- [ ] TTS quality premium
- [ ] Full feature set available

---

### Test Case IT-PERF-002-03: Mode Transition Smoothness

**Objective**: Verify smooth transition between modes.

**Test Steps**:
1. In efficient mode
2. Connect charger
3. Transition to performance mode

**Expected Results**:
- [ ] Transition < 1 second
- [ ] No audio interruption
- [ ] Settings applied atomically
- [ ] No user disruption

---

### Test Case IT-PERF-002-04: Battery Drain Rate

**Objective**: Measure battery consumption.

**Test Steps**:
1. Full charge
2. Run 30-minute interpretation
3. Measure battery drain

**Expected Results**:
- [ ] Drain < 15% per hour
- [ ] Consistent with target
- [ ] No abnormal consumption
- [ ] Within App Store guidelines

---

### Test Case IT-PERF-002-05: Thermal Throttling Detection

**Objective**: Verify response to thermal pressure.

**Test Steps**:
1. Heavy processing triggers heat
2. System throttles
3. Verify app adaptation

**Expected Results**:
- [ ] Thermal state detected
- [ ] Processing reduced
- [ ] Quality may decrease
- [ ] Device cools down

---

## WF-PERF-003: Audio Buffer Pooling

### Test Case IT-PERF-003-01: Pool Initialization

**Objective**: Verify buffer pool pre-allocates correctly.

**Test Steps**:
1. Initialize pool with size 10
2. Verify pre-allocated buffers

**Expected Results**:
- [ ] 10 buffers pre-allocated
- [ ] Memory accounted for
- [ ] Buffers reusable
- [ ] Format correct

```swift
func testBufferPoolInitialization() {
    let pool = AudioBufferPool(initialSize: 10, format: audioFormat)

    XCTAssertEqual(pool.availableCount, 10)
    XCTAssertEqual(pool.totalAllocated, 10)
}
```

---

### Test Case IT-PERF-003-02: Buffer Acquire and Release

**Objective**: Verify buffer reuse cycle.

**Test Steps**:
1. Acquire buffer from pool
2. Use buffer
3. Release back to pool
4. Verify reusability

**Expected Results**:
- [ ] Buffer acquired
- [ ] frameLength reset on release
- [ ] Buffer back in pool
- [ ] Same instance reused

---

### Test Case IT-PERF-003-03: Pool Empty Behavior

**Objective**: Verify behavior when pool exhausted.

**Test Steps**:
1. Acquire all 10 buffers
2. Request 11th buffer
3. Verify allocation

**Expected Results**:
- [ ] New buffer allocated
- [ ] Pool grows temporarily
- [ ] Warning logged
- [ ] Released buffer returns to pool

---

### Test Case IT-PERF-003-04: Pool Size Limit

**Objective**: Verify pool doesn't grow unbounded.

**Test Steps**:
1. Configure max pool size = 20
2. Allocate many buffers
3. Release all
4. Verify pool capped

**Expected Results**:
- [ ] Pool accepts up to 20
- [ ] Excess released (not pooled)
- [ ] Memory bounded
- [ ] Performance maintained

---

### Test Case IT-PERF-003-05: Thread Safety

**Objective**: Verify pool is thread-safe.

**Test Steps**:
1. Concurrent acquire/release from multiple threads
2. Verify no crashes or corruption

**Expected Results**:
- [ ] No data races
- [ ] Lock works correctly
- [ ] All operations complete
- [ ] Pool consistent

---

## WF-PERF-004: API Latency Monitoring

### Test Case IT-PERF-004-01: Latency Recording

**Objective**: Verify latency measurements recorded.

**Test Steps**:
1. Make API request
2. Record latency
3. Verify metric stored

**Expected Results**:
- [ ] Start/end time captured
- [ ] Duration calculated correctly
- [ ] Metric stored
- [ ] Rolling window maintained

```swift
func testLatencyRecording() async throws {
    let metrics = PerformanceMetrics.shared

    let startTime = CFAbsoluteTimeGetCurrent()
    try await apiClient.translateRequest()
    let endTime = CFAbsoluteTimeGetCurrent()

    let latency = metrics.getLatency(for: "translation")
    XCTAssertNotNil(latency)
    XCTAssertGreaterThan(latency!.last!, 0)
}
```

---

### Test Case IT-PERF-004-02: Percentile Calculations

**Objective**: Verify P50, P95, P99 calculations.

**Test Steps**:
1. Record 100 latency samples
2. Calculate percentiles
3. Verify statistics

**Expected Results**:
- [ ] P50 (median) calculated
- [ ] P95 calculated
- [ ] P99 calculated
- [ ] Min/max correct

---

### Test Case IT-PERF-004-03: Latency Alerting

**Objective**: Verify alerts when latency exceeds threshold.

**Test Steps**:
1. Configure threshold = 500ms
2. Record latency > 500ms
3. Verify alert triggered

**Expected Results**:
- [ ] Threshold exceeded detected
- [ ] Alert/log generated
- [ ] Metrics dashboard updated
- [ ] Investigation possible

---

### Test Case IT-PERF-004-04: Report Generation

**Objective**: Verify performance report generated.

**Test Steps**:
1. Run operations for 5 minutes
2. Generate report
3. Verify content

**Expected Results**:
- [ ] Report contains all metrics
- [ ] STT latency included
- [ ] Translation latency included
- [ ] TTS latency included

---

### Test Case IT-PERF-004-05: Dashboard Display

**Objective**: Verify metrics displayed in debug UI.

**Test Steps**:
1. Enable performance dashboard
2. Run operations
3. Verify real-time display

**Expected Results**:
- [ ] Dashboard visible
- [ ] Metrics update in real-time
- [ ] Color coding (green/yellow/red)
- [ ] Historical graph

---

## Cache Efficiency

### Test Case IT-PERF-CACHE-01: Cache Hit Rate Tracking

**Objective**: Verify cache hit rate calculated.

**Test Steps**:
1. Make 100 requests (50 unique)
2. Calculate hit rate
3. Verify 50%

**Expected Results**:
- [ ] Hits = ~50
- [ ] Misses = ~50
- [ ] Hit rate = ~50%
- [ ] Accurate tracking

---

### Test Case IT-PERF-CACHE-02: Low Hit Rate Alert

**Objective**: Verify alert when hit rate low.

**Test Steps**:
1. Hit rate drops below 50%
2. Verify warning logged

**Expected Results**:
- [ ] Low rate detected
- [ ] Warning logged
- [ ] Suggestion: increase cache size
- [ ] Metrics tracked

---

### Test Case IT-PERF-CACHE-03: Cache Size vs Hit Rate

**Objective**: Analyze cache size impact.

**Test Steps**:
1. Small cache (100): measure hit rate
2. Large cache (1000): measure hit rate
3. Compare

**Expected Results**:
- [ ] Larger cache = higher hit rate
- [ ] Diminishing returns
- [ ] Optimal size identified
- [ ] Memory trade-off documented

---

## Benchmark Suite

### Test Case IT-PERF-BENCH-01: STT Latency Benchmark

**Objective**: Benchmark speech recognition latency.

**Test Steps**:
1. Process 100 audio samples
2. Measure each latency
3. Calculate statistics

**Expected Results**:
- [ ] P95 < 280ms
- [ ] Average < 200ms
- [ ] Max < 500ms
- [ ] Consistent performance

```swift
func testSTTLatencyBenchmark() throws {
    let options = XCTMeasureOptions()
    options.iterationCount = 100

    measure(options: options) {
        let _ = try? sttManager.recognizeSync(audio: testAudio)
    }
}
```

---

### Test Case IT-PERF-BENCH-02: Translation Latency Benchmark

**Objective**: Benchmark translation latency.

**Test Steps**:
1. Translate 100 sentences
2. Measure each latency
3. Calculate statistics

**Expected Results**:
- [ ] P95 < 520ms (cloud)
- [ ] P95 < 200ms (local)
- [ ] Consistent performance
- [ ] No outliers > 1s

---

### Test Case IT-PERF-BENCH-03: TTS Latency Benchmark

**Objective**: Benchmark TTS synthesis latency.

**Test Steps**:
1. Synthesize 100 utterances
2. Measure time to first audio
3. Calculate statistics

**Expected Results**:
- [ ] P95 < 180ms (system)
- [ ] P95 < 500ms (CoeFont)
- [ ] Consistent quality
- [ ] No audio glitches

---

### Test Case IT-PERF-BENCH-04: End-to-End Pipeline

**Objective**: Benchmark complete interpretation pipeline.

**Test Steps**:
1. Audio input to TTS output
2. Measure 100 utterances
3. Target: < 1 second total

**Expected Results**:
- [ ] Total latency < 1 second (P50)
- [ ] Total latency < 1.5 seconds (P95)
- [ ] Streaming helps latency
- [ ] Acceptable user experience

---

### Test Case IT-PERF-BENCH-05: Memory Under Load

**Objective**: Measure memory during sustained load.

**Test Steps**:
1. 30-minute interpretation session
2. Monitor memory throughout
3. Verify stability

**Expected Results**:
- [ ] Peak < 200MB active
- [ ] No memory growth trend
- [ ] Cleanup effective
- [ ] No OOM risk

---

## Resource Usage Targets

### Test Case IT-PERF-TARGET-01: Idle Memory

**Objective**: Verify idle memory within target.

**Test Steps**:
1. Launch app
2. Stay idle 30 seconds
3. Measure memory

**Expected Results**:
- [ ] Target: < 50MB
- [ ] Max acceptable: 100MB
- [ ] Baseline recorded
- [ ] No background activity

---

### Test Case IT-PERF-TARGET-02: Active CPU

**Objective**: Verify CPU usage during interpretation.

**Test Steps**:
1. Start interpretation
2. Measure CPU usage
3. Average over 1 minute

**Expected Results**:
- [ ] Target: < 40% average
- [ ] Max: < 60% peak
- [ ] Consistent levels
- [ ] No runaway processes

---

### Test Case IT-PERF-TARGET-03: Cold Start Time

**Objective**: Verify cold start within budget.

**Test Steps**:
1. Kill app
2. Launch fresh
3. Measure to interactive

**Expected Results**:
- [ ] Target: < 2 seconds
- [ ] Max: < 3 seconds
- [ ] Splash to home smooth
- [ ] No blocking operations

---

## Test Data Fixtures

### Audio Samples for Benchmarks

| Sample | Duration | Language | Content |
|--------|----------|----------|---------|
| `bench_short.wav` | 2s | Japanese | Short greeting |
| `bench_medium.wav` | 10s | Japanese | Paragraph |
| `bench_long.wav` | 30s | Japanese | Long text |

### Target Metrics

| Metric | Target | Max | Unit |
|--------|--------|-----|------|
| Idle memory | 50 | 100 | MB |
| Active memory | 150 | 200 | MB |
| Idle CPU | 5 | 10 | % |
| Active CPU | 40 | 60 | % |
| Cold start | 2 | 3 | seconds |
| STT latency | 200 | 280 | ms |
| Translation latency | 450 | 520 | ms |
| TTS latency | 150 | 180 | ms |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 35 test cases | AI Agent |
