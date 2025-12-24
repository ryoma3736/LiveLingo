# IT-CORE: Core Interpretation Integration Tests

## Overview

This document defines integration tests for the core interpretation pipeline based on workflows WF-CORE-001 through WF-CORE-005. These tests verify the end-to-end integration of STT, Translation, and TTS components.

**Priority**: P0-Critical
**Total Test Cases**: 45
**Estimated Execution Time**: 15 minutes

---

## Test Environment

### Required Components
- `SpeechRecognitionManager` (STT)
- `TranslationManager` (Apple/OpenAI/Anthropic)
- `TTSManager` (AVSpeechSynthesizer/CoeFont)
- `InterpretationViewModel`
- `AudioSessionManager`

### Mock Dependencies
- `MockSFSpeechRecognizer`
- `MockTranslationService`
- `MockAVSpeechSynthesizer`
- `MockCoeFontAPIClient`

### Test Data
- Audio samples: Japanese speech (5-30 seconds)
- Expected transcriptions
- Expected translations
- Audio output verification samples

---

## WF-CORE-001: Main Interpretation Loop

### Test Case IT-CORE-001-01: Full Pipeline Success

**Objective**: Verify complete STT → Translation → TTS pipeline executes successfully.

**Preconditions**:
- Audio session configured for playAndRecord
- Microphone permission granted
- Network connectivity available

**Test Steps**:
1. Initialize InterpretationViewModel with source=Japanese, target=English
2. Call `startInterpretation()`
3. Feed audio sample containing "こんにちは"
4. Wait for STT partial result
5. Wait for translation result
6. Wait for TTS audio output

**Expected Results**:
- [ ] STT returns "こんにちは" within 500ms
- [ ] Translation returns "Hello" within 800ms
- [ ] TTS audio plays within 300ms after translation
- [ ] Total end-to-end latency < 1.6 seconds

**Verification**:
```swift
func testFullPipelineSuccess() async throws {
    let viewModel = InterpretationViewModel()
    viewModel.sourceLanguage = .japanese
    viewModel.targetLanguage = .english

    let expectation = expectation(description: "Full pipeline")

    viewModel.onTTSPlaybackStarted = {
        expectation.fulfill()
    }

    viewModel.startInterpretation()
    feedAudioSample("konnichiwa.wav")

    await fulfillment(of: [expectation], timeout: 2.0)

    XCTAssertEqual(viewModel.recognizedText, "こんにちは")
    XCTAssertEqual(viewModel.translatedText, "Hello")
    XCTAssertTrue(viewModel.isTTSPlaying)
}
```

---

### Test Case IT-CORE-001-02: Pipeline with Multiple Utterances

**Objective**: Verify pipeline handles sequential utterances correctly.

**Preconditions**:
- Interpretation session active
- Buffer management enabled

**Test Steps**:
1. Feed first utterance: "おはようございます"
2. Wait for TTS completion
3. Feed second utterance: "今日の天気は？"
4. Wait for TTS completion
5. Feed third utterance: "ありがとう"
6. Wait for TTS completion

**Expected Results**:
- [ ] Each utterance processed independently
- [ ] No audio overlap between TTS outputs
- [ ] All translations accurate
- [ ] Memory usage stable (no leak)

---

### Test Case IT-CORE-001-03: Pipeline Interruption During STT

**Objective**: Verify graceful handling when STT is interrupted mid-recognition.

**Test Steps**:
1. Start interpretation
2. Begin feeding long audio sample
3. Call `stopInterpretation()` at 50% progress
4. Verify state cleanup

**Expected Results**:
- [ ] STT recognition cancelled immediately
- [ ] No partial translation triggered
- [ ] No orphaned audio buffers
- [ ] ViewModel state reset to idle

---

### Test Case IT-CORE-001-04: Pipeline Recovery After Error

**Objective**: Verify pipeline can recover after transient errors.

**Test Steps**:
1. Configure MockTranslationService to fail first request
2. Start interpretation
3. Feed audio sample
4. Observe error handling
5. Feed second audio sample
6. Verify successful processing

**Expected Results**:
- [ ] First translation error displayed to user
- [ ] Second utterance processed successfully
- [ ] Error count incremented
- [ ] Recovery logged

---

### Test Case IT-CORE-001-05: Pipeline with Silence Detection

**Objective**: Verify silence triggers pipeline completion.

**Test Steps**:
1. Start interpretation
2. Feed audio with 500ms speech followed by 500ms silence
3. Wait for pause detection
4. Verify translation triggered

**Expected Results**:
- [ ] Pause detected within 100ms of silence threshold
- [ ] Translation triggered with complete utterance
- [ ] TTS plays after translation
- [ ] Pipeline ready for next utterance

---

## WF-CORE-002: Wait-k Streaming Interpretation

### Test Case IT-CORE-002-01: Wait-k=3 Token Streaming

**Objective**: Verify Wait-k strategy triggers translation after k tokens.

**Test Steps**:
1. Configure Wait-k with k=3
2. Start streaming interpretation
3. Feed audio sample
4. Monitor partial results

**Expected Results**:
- [ ] First partial result after 3 tokens detected
- [ ] Translation request sent at k-token boundary
- [ ] Streaming translation merged correctly
- [ ] Final result matches expected

```swift
func testWaitKStreaming() async throws {
    let viewModel = InterpretationViewModel()
    viewModel.streamingConfig = .waitK(k: 3)

    var partialTranslations: [String] = []
    viewModel.onPartialTranslation = { text in
        partialTranslations.append(text)
    }

    viewModel.startInterpretation()
    feedAudioSample("long_sentence.wav")

    await waitForPipelineCompletion()

    XCTAssertGreaterThan(partialTranslations.count, 1)
    XCTAssertEqual(viewModel.translatedText, expectedFullTranslation)
}
```

---

### Test Case IT-CORE-002-02: Streaming with Token Overlap

**Objective**: Verify overlapping token handling in Wait-k mode.

**Test Steps**:
1. Enable Wait-k with overlap window = 2
2. Feed continuous speech
3. Monitor token boundaries
4. Verify no duplicates in output

**Expected Results**:
- [ ] Overlap tokens properly deduplicated
- [ ] Translation coherent across boundaries
- [ ] No stuttering in TTS output
- [ ] Latency maintained under target

---

### Test Case IT-CORE-002-03: Streaming Cancellation Mid-Token

**Objective**: Verify streaming can be cancelled cleanly.

**Test Steps**:
1. Start Wait-k streaming
2. Cancel after 2 partial results
3. Verify cleanup

**Expected Results**:
- [ ] Pending translations cancelled
- [ ] TTS queue cleared
- [ ] No lingering callbacks
- [ ] Memory properly released

---

### Test Case IT-CORE-002-04: Streaming with Variable Speech Rate

**Objective**: Verify Wait-k adapts to fast/slow speakers.

**Test Steps**:
1. Feed slow speech (< 100 words/min)
2. Verify Wait-k timing adjustment
3. Feed fast speech (> 200 words/min)
4. Verify buffer handling

**Expected Results**:
- [ ] Slow speech: longer wait before translation
- [ ] Fast speech: Wait-k threshold maintained
- [ ] No buffer overflow
- [ ] Quality consistent

---

## WF-CORE-003: Dual Speaker Mode

### Test Case IT-CORE-003-01: Two Speaker Detection and Routing

**Objective**: Verify dual speaker mode correctly routes audio to separate channels.

**Preconditions**:
- SpeakerDiarizer enabled
- Two distinct voice profiles configured

**Test Steps**:
1. Enable dual speaker mode
2. Feed audio with Speaker A (Japanese)
3. Feed audio with Speaker B (English)
4. Verify separate translation paths

**Expected Results**:
- [ ] Speaker A audio routed to JA→EN translation
- [ ] Speaker B audio routed to EN→JA translation
- [ ] No cross-contamination between channels
- [ ] Speaker labels displayed correctly

```swift
func testDualSpeakerRouting() async throws {
    let viewModel = InterpretationViewModel()
    viewModel.speakerMode = .dual
    viewModel.speakerALanguage = .japanese
    viewModel.speakerBLanguage = .english

    viewModel.startInterpretation()

    feedAudioSample("speaker_a_japanese.wav")
    await waitForProcessing()

    XCTAssertEqual(viewModel.speakerARecognizedText, "こんにちは")
    XCTAssertEqual(viewModel.speakerATranslatedText, "Hello")

    feedAudioSample("speaker_b_english.wav")
    await waitForProcessing()

    XCTAssertEqual(viewModel.speakerBRecognizedText, "Nice to meet you")
    XCTAssertEqual(viewModel.speakerBTranslatedText, "はじめまして")
}
```

---

### Test Case IT-CORE-003-02: Speaker Overlap Handling

**Objective**: Verify system handles simultaneous speakers.

**Test Steps**:
1. Enable dual speaker mode
2. Feed overlapping audio from both speakers
3. Observe diarization behavior

**Expected Results**:
- [ ] Diarizer separates overlapping speech
- [ ] Both utterances captured
- [ ] Priority given to dominant speaker
- [ ] Warning logged for overlap

---

### Test Case IT-CORE-003-03: Speaker Identification Accuracy

**Objective**: Verify speaker identification meets accuracy threshold.

**Test Steps**:
1. Train speaker profiles with 10-second samples
2. Feed 20 alternating utterances
3. Calculate identification accuracy

**Expected Results**:
- [ ] Speaker identification accuracy > 95%
- [ ] False positive rate < 2%
- [ ] Processing latency < 50ms per utterance

---

### Test Case IT-CORE-003-04: Dual Mode TTS Separation

**Objective**: Verify TTS output distinguishes speakers.

**Test Steps**:
1. Configure different voices for each speaker
2. Process dual speaker conversation
3. Verify TTS voice assignment

**Expected Results**:
- [ ] Speaker A uses configured voice (e.g., Kyoko)
- [ ] Speaker B uses different voice (e.g., Samantha)
- [ ] No voice mixing between speakers
- [ ] Audio output clearly distinguishable

---

### Test Case IT-CORE-003-05: Dual to Single Mode Transition

**Objective**: Verify smooth transition between speaker modes.

**Test Steps**:
1. Start in dual speaker mode
2. Switch to single speaker mode mid-session
3. Continue processing
4. Switch back to dual mode

**Expected Results**:
- [ ] Mode transition within 100ms
- [ ] No audio discontinuity
- [ ] Settings preserved across transitions
- [ ] History maintained correctly

---

## WF-CORE-004: Single Speaker Mode

### Test Case IT-CORE-004-01: Single Speaker Basic Flow

**Objective**: Verify single speaker mode with language pair.

**Test Steps**:
1. Enable single speaker mode
2. Set source=Japanese, target=English
3. Feed Japanese speech
4. Verify one-directional translation

**Expected Results**:
- [ ] Only JA→EN translation active
- [ ] No reverse translation triggered
- [ ] Simpler audio routing
- [ ] Lower resource consumption

---

### Test Case IT-CORE-004-02: Single Speaker Language Swap

**Objective**: Verify language swap in single speaker mode.

**Test Steps**:
1. Start with JA→EN
2. Process utterance
3. Tap swap button
4. Process next utterance (now EN→JA)

**Expected Results**:
- [ ] Language pair swapped immediately
- [ ] New utterance processed with new direction
- [ ] UI reflects swap
- [ ] No processing gap

---

### Test Case IT-CORE-004-03: Single Speaker with Auto-Detect

**Objective**: Verify auto language detection in single mode.

**Test Steps**:
1. Enable auto-detect for source language
2. Feed Japanese speech
3. Verify detected language
4. Feed English speech
5. Verify language switch

**Expected Results**:
- [ ] Japanese detected correctly
- [ ] English detected on switch
- [ ] Translation direction adjusted
- [ ] Minimal detection latency

---

## WF-CORE-005: Pause Detection

### Test Case IT-CORE-005-01: 500ms Pause Threshold

**Objective**: Verify pause detection at configured threshold.

**Test Steps**:
1. Configure pause threshold = 500ms
2. Feed speech followed by 500ms silence
3. Observe pause callback

**Expected Results**:
- [ ] Pause detected at 500ms ± 50ms
- [ ] Translation triggered immediately
- [ ] isPaused state = true
- [ ] Audio engine remains active

```swift
func testPauseDetection() async throws {
    let viewModel = InterpretationViewModel()
    viewModel.pauseThresholdMs = 500

    let pauseExpectation = expectation(description: "Pause detected")
    viewModel.onPauseDetected = {
        pauseExpectation.fulfill()
    }

    viewModel.startInterpretation()
    feedAudioSample("speech_with_pause.wav")

    await fulfillment(of: [pauseExpectation], timeout: 1.0)
    XCTAssertTrue(viewModel.isPaused)
}
```

---

### Test Case IT-CORE-005-02: Pause with Background Noise

**Objective**: Verify pause detection distinguishes silence from noise.

**Test Steps**:
1. Set noise threshold = -40dB
2. Feed speech followed by ambient noise (< -40dB)
3. Verify pause detection
4. Feed speech followed by noise (> -40dB)
5. Verify no false pause

**Expected Results**:
- [ ] Quiet noise triggers pause
- [ ] Loud noise does not trigger pause
- [ ] VAD (Voice Activity Detection) accurate
- [ ] No false positives

---

### Test Case IT-CORE-005-03: Pause Cancellation on Speech Resume

**Objective**: Verify pause cancelled when speech resumes.

**Test Steps**:
1. Feed speech followed by 300ms silence
2. Resume speech before 500ms threshold
3. Verify no pause triggered
4. Continue with complete sentence

**Expected Results**:
- [ ] Pause timer cancelled
- [ ] Sentence continues accumulating
- [ ] No premature translation
- [ ] Natural flow maintained

---

### Test Case IT-CORE-005-04: Long Pause (> 2 seconds)

**Objective**: Verify extended pause handling.

**Test Steps**:
1. Feed speech followed by 5 second silence
2. Resume speech
3. Verify new utterance starts fresh

**Expected Results**:
- [ ] First utterance finalized
- [ ] New utterance context reset
- [ ] Session remains active
- [ ] No timeout triggered

---

### Test Case IT-CORE-005-05: Pause Detection Performance

**Objective**: Verify pause detection CPU efficiency.

**Test Steps**:
1. Run 10-minute continuous interpretation
2. Monitor pause detection overhead
3. Measure CPU impact

**Expected Results**:
- [ ] Pause detection < 5% CPU
- [ ] No memory growth
- [ ] Consistent latency
- [ ] Battery impact minimal

---

## End-to-End Integration Scenarios

### Test Case IT-CORE-E2E-01: 5-Minute Continuous Session

**Objective**: Verify system stability over extended session.

**Test Steps**:
1. Start interpretation session
2. Feed 5 minutes of alternating speech
3. Monitor all metrics continuously
4. Stop session

**Expected Results**:
- [ ] All utterances processed correctly
- [ ] Memory stable within 20% of baseline
- [ ] No audio glitches
- [ ] Latency consistent throughout
- [ ] No crashes or ANRs

---

### Test Case IT-CORE-E2E-02: Rapid Language Switching

**Objective**: Verify stability during frequent language changes.

**Test Steps**:
1. Start session with JA→EN
2. Feed utterance
3. Switch to EN→JA
4. Feed utterance
5. Repeat 10 times rapidly

**Expected Results**:
- [ ] All switches processed
- [ ] No race conditions
- [ ] Correct translation direction each time
- [ ] UI responsive throughout

---

### Test Case IT-CORE-E2E-03: Resource Cleanup After Session

**Objective**: Verify complete cleanup after interpretation ends.

**Test Steps**:
1. Start 30-second session
2. Stop interpretation
3. Wait 5 seconds
4. Check resource state

**Expected Results**:
- [ ] Audio engine stopped
- [ ] Speech recognizer released
- [ ] Translation connections closed
- [ ] Memory returned to baseline
- [ ] No background audio processing

---

## Test Data Fixtures

### Audio Samples

| Sample ID | Content | Duration | Language | Speaker |
|-----------|---------|----------|----------|---------|
| `ja_greeting_01.wav` | "こんにちは" | 1.2s | Japanese | Female |
| `ja_sentence_01.wav` | "今日の天気はいいですね" | 2.8s | Japanese | Male |
| `en_greeting_01.wav` | "Hello, how are you?" | 1.5s | English | Female |
| `en_sentence_01.wav` | "The weather is nice today" | 2.0s | English | Male |
| `ja_long_01.wav` | Long paragraph | 30s | Japanese | Female |
| `overlap_01.wav` | Two speakers overlapping | 5s | Mixed | Both |

### Expected Translations

| Input | Expected Output |
|-------|-----------------|
| こんにちは | Hello |
| 今日の天気はいいですね | The weather is nice today |
| Hello, how are you? | こんにちは、お元気ですか？ |
| The weather is nice today | 今日はいい天気ですね |

---

## Mocking Strategy

### MockSpeechRecognizer

```swift
class MockSpeechRecognizer: SpeechRecognizing {
    var simulatedResults: [PartialResult] = []
    var shouldFail: Bool = false
    var latency: TimeInterval = 0.1

    func recognize(audio: AudioBuffer) async throws -> RecognitionResult {
        try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        if shouldFail { throw RecognitionError.unavailable }
        return simulatedResults
    }
}
```

### MockTranslationService

```swift
class MockTranslationService: TranslationProviding {
    var translationMap: [String: String] = [:]
    var shouldFail: Bool = false
    var latency: TimeInterval = 0.2

    func translate(text: String, from: Language, to: Language) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        if shouldFail { throw TranslationError.networkError }
        return translationMap[text] ?? "[Translation not found]"
    }
}
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 45 test cases | AI Agent |
