# IT-STT: Speech Recognition Integration Tests

## Overview

This document defines integration tests for the Speech-to-Text (STT) subsystem based on workflows WF-STT-001 through WF-STT-008. These tests verify speech recognition accuracy, real-time processing, and fallback mechanisms.

**Priority**: P0-Critical
**Total Test Cases**: 52
**Estimated Execution Time**: 20 minutes

---

## Test Environment

### Required Components
- `SpeechRecognitionManager`
- `SFSpeechRecognizer` (Apple Speech)
- `AVAudioEngine`
- `WhisperKitManager` (fallback)
- `VADProcessor` (Voice Activity Detection)
- `SpeakerDiarizer`

### Mock Dependencies
- `MockAudioEngine`
- `MockSFSpeechRecognizer`
- `MockWhisperKit`
- `MockAudioBuffer`

### Test Data
- Audio samples in multiple languages
- Known transcriptions for accuracy testing
- Edge case audio (noise, accents, fast speech)

---

## WF-STT-001: SFSpeechRecognizer Initialization

### Test Case IT-STT-001-01: Successful Initialization

**Objective**: Verify SFSpeechRecognizer initializes correctly for specified locale.

**Preconditions**:
- Speech recognition permission granted
- Network available
- Locale supported

**Test Steps**:
1. Request speech recognition authorization
2. Initialize SFSpeechRecognizer with Japanese locale
3. Verify availability
4. Check delegate assignment

**Expected Results**:
- [ ] Authorization status = .authorized
- [ ] isAvailable = true
- [ ] Locale = ja-JP
- [ ] Delegate set correctly

```swift
func testSFSpeechRecognizerInitialization() async throws {
    let manager = SpeechRecognitionManager()

    try await manager.initialize(locale: Locale(identifier: "ja-JP"))

    XCTAssertTrue(manager.isAvailable)
    XCTAssertEqual(manager.currentLocale.identifier, "ja-JP")
    XCTAssertNotNil(manager.recognizer)
}
```

---

### Test Case IT-STT-001-02: Initialization with Unsupported Locale

**Objective**: Verify graceful handling of unsupported locale.

**Test Steps**:
1. Attempt to initialize with unsupported locale
2. Verify fallback behavior

**Expected Results**:
- [ ] Error thrown or fallback triggered
- [ ] User-friendly error message
- [ ] Alternative locale suggested
- [ ] App remains stable

---

### Test Case IT-STT-001-03: Initialization Without Permission

**Objective**: Verify error handling when permission denied.

**Test Steps**:
1. Revoke speech recognition permission
2. Attempt initialization
3. Verify permission request flow

**Expected Results**:
- [ ] Error: permissionDenied thrown
- [ ] Permission request UI shown
- [ ] Initialization retryable after grant

---

### Test Case IT-STT-001-04: Reinitialization After Locale Change

**Objective**: Verify recognizer reconfigures on locale change.

**Test Steps**:
1. Initialize with Japanese
2. Change to English
3. Verify new recognizer created
4. Process English audio

**Expected Results**:
- [ ] Old recognizer released
- [ ] New recognizer initialized
- [ ] English audio processed correctly
- [ ] No memory leak

---

### Test Case IT-STT-001-05: Initialization Performance

**Objective**: Verify initialization completes within time budget.

**Test Steps**:
1. Measure initialization time
2. Repeat 5 times
3. Calculate average

**Expected Results**:
- [ ] Average initialization < 500ms
- [ ] No initialization > 1 second
- [ ] Consistent timing
- [ ] No UI freeze

---

## WF-STT-002: Real-Time Speech Recognition

### Test Case IT-STT-002-01: Audio Buffer Processing (512 frames)

**Objective**: Verify audio buffers processed at configured size.

**Test Steps**:
1. Configure buffer size = 512 frames
2. Start audio engine
3. Install tap on input node
4. Feed audio sample
5. Verify buffer delivery

**Expected Results**:
- [ ] Buffers delivered at 512 frames
- [ ] Sample rate = 16kHz
- [ ] No buffer drops
- [ ] Latency < 32ms per buffer

```swift
func testAudioBufferProcessing() async throws {
    let manager = SpeechRecognitionManager()
    manager.bufferSize = 512
    manager.sampleRate = 16000

    var receivedBufferSizes: [Int] = []
    manager.onBufferReceived = { buffer in
        receivedBufferSizes.append(Int(buffer.frameLength))
    }

    try await manager.startRecognition()
    feedAudioSample("test_speech.wav")
    try await Task.sleep(nanoseconds: 1_000_000_000)
    await manager.stopRecognition()

    XCTAssertTrue(receivedBufferSizes.allSatisfy { $0 == 512 })
}
```

---

### Test Case IT-STT-002-02: Recognition Request Creation

**Objective**: Verify recognition request configured correctly.

**Test Steps**:
1. Start recognition
2. Inspect request configuration
3. Verify settings

**Expected Results**:
- [ ] shouldReportPartialResults = true
- [ ] taskHint = .dictation (or appropriate)
- [ ] contextualStrings set (if any)
- [ ] Request tied to correct recognizer

---

### Test Case IT-STT-002-03: Recognition Task Management

**Objective**: Verify task lifecycle management.

**Test Steps**:
1. Start recognition
2. Cancel task
3. Start new recognition
4. Complete normally

**Expected Results**:
- [ ] Task cancelled immediately
- [ ] Resources released
- [ ] New task starts cleanly
- [ ] No orphaned tasks

---

### Test Case IT-STT-002-04: Audio Engine Node Graph

**Objective**: Verify correct audio node configuration.

**Test Steps**:
1. Inspect audio engine graph
2. Verify input node configuration
3. Check format conversion
4. Verify tap installation

**Expected Results**:
- [ ] Input node active
- [ ] Format = mono, 16kHz
- [ ] Tap installed on correct node
- [ ] No format mismatch errors

---

### Test Case IT-STT-002-05: High CPU Usage Handling

**Objective**: Verify recognition degrades gracefully under load.

**Test Steps**:
1. Consume 80% CPU externally
2. Start recognition
3. Monitor accuracy and latency
4. Remove CPU load

**Expected Results**:
- [ ] Recognition continues (may be slower)
- [ ] No crashes
- [ ] Quality indication to user
- [ ] Recovery when load removed

---

## WF-STT-003: Partial/Final Results

### Test Case IT-STT-003-01: Partial Result Streaming

**Objective**: Verify partial results delivered incrementally.

**Test Steps**:
1. Feed 10-word sentence
2. Monitor partial results
3. Count partial result callbacks
4. Verify final result

**Expected Results**:
- [ ] Multiple partial results received
- [ ] Each partial builds on previous
- [ ] Final result is complete sentence
- [ ] No partial after final

```swift
func testPartialResultStreaming() async throws {
    let manager = SpeechRecognitionManager()

    var partialResults: [String] = []
    var finalResult: String?

    manager.onPartialResult = { text in
        partialResults.append(text)
    }
    manager.onFinalResult = { text in
        finalResult = text
    }

    try await manager.startRecognition()
    feedAudioSample("ten_word_sentence.wav")

    await waitForFinalResult()

    XCTAssertGreaterThan(partialResults.count, 3)
    XCTAssertEqual(finalResult, "expected full transcription here")
}
```

---

### Test Case IT-STT-003-02: Final Result Confidence Score

**Objective**: Verify confidence scores provided with results.

**Test Steps**:
1. Process clear audio
2. Get confidence score
3. Process noisy audio
4. Compare confidence scores

**Expected Results**:
- [ ] Clear audio confidence > 0.9
- [ ] Noisy audio confidence < 0.7
- [ ] Confidence values reasonable
- [ ] Low confidence flagged

---

### Test Case IT-STT-003-03: Alternative Transcriptions

**Objective**: Verify alternative transcriptions available.

**Test Steps**:
1. Process ambiguous audio
2. Request transcriptionAlternatives
3. Inspect alternatives

**Expected Results**:
- [ ] Primary transcription provided
- [ ] Alternatives available
- [ ] Alternatives ranked by confidence
- [ ] User can select alternative

---

### Test Case IT-STT-003-04: isFinal Flag Accuracy

**Objective**: Verify isFinal correctly indicates completion.

**Test Steps**:
1. Process audio with clear ending
2. Monitor isFinal flag
3. Verify no false positives

**Expected Results**:
- [ ] isFinal = true only at end
- [ ] Silence triggers isFinal
- [ ] No premature isFinal
- [ ] Single isFinal per utterance

---

### Test Case IT-STT-003-05: Result Timing Accuracy

**Objective**: Verify timestamp accuracy in results.

**Test Steps**:
1. Process audio with known timing
2. Extract word timestamps
3. Compare to actual

**Expected Results**:
- [ ] Word timestamps within 100ms
- [ ] Segment boundaries accurate
- [ ] Duration matches audio
- [ ] Timestamps monotonically increasing

---

## WF-STT-004: Voice Activity Detection (VAD)

### Test Case IT-STT-004-01: Speech Start Detection

**Objective**: Verify VAD detects speech onset.

**Test Steps**:
1. Feed audio with 1s silence then speech
2. Monitor VAD state
3. Verify speech detection time

**Expected Results**:
- [ ] isSpeaking = false during silence
- [ ] isSpeaking = true at speech start
- [ ] Detection latency < 100ms
- [ ] No false starts

---

### Test Case IT-STT-004-02: Speech End Detection (500ms Pause)

**Objective**: Verify VAD detects 500ms pause.

**Test Steps**:
1. Feed speech followed by 500ms silence
2. Monitor VAD pause detection
3. Verify timing accuracy

**Expected Results**:
- [ ] Pause detected at 500ms ± 50ms
- [ ] isSpeaking = false after pause
- [ ] Translation triggered
- [ ] Ready for next utterance

```swift
func testVADPauseDetection() async throws {
    let vad = VADProcessor()
    vad.pauseThreshold = 0.5 // 500ms

    var pauseDetected = false
    vad.onPauseDetected = {
        pauseDetected = true
    }

    feedAudioSample("speech_then_silence.wav")
    try await Task.sleep(nanoseconds: 700_000_000)

    XCTAssertTrue(pauseDetected)
}
```

---

### Test Case IT-STT-004-03: Background Noise Immunity

**Objective**: Verify VAD ignores background noise.

**Test Steps**:
1. Configure noise threshold = -40dB
2. Feed ambient noise at -45dB
3. Verify no false speech detection
4. Feed speech at -30dB
5. Verify detection

**Expected Results**:
- [ ] Noise ignored
- [ ] Speech detected correctly
- [ ] Threshold configurable
- [ ] No missed detections

---

### Test Case IT-STT-004-04: Rapid Speech Alternation

**Objective**: Verify VAD handles rapid speech bursts.

**Test Steps**:
1. Feed: speech(1s) - pause(200ms) - speech(1s)
2. Verify continuous detection
3. No false pause trigger

**Expected Results**:
- [ ] Short pause not treated as end
- [ ] Continuous transcription
- [ ] 500ms threshold respected
- [ ] Correct utterance boundaries

---

### Test Case IT-STT-004-05: VAD Energy Calculation

**Objective**: Verify energy calculation accuracy.

**Test Steps**:
1. Feed calibrated audio
2. Compare calculated dB to expected
3. Verify threshold operation

**Expected Results**:
- [ ] dB calculation accurate ± 2dB
- [ ] Threshold comparison correct
- [ ] Edge cases handled
- [ ] Performance acceptable

---

## WF-STT-005: Pause Detection

### Test Case IT-STT-005-01: Configurable Pause Threshold

**Objective**: Verify pause threshold is configurable.

**Test Steps**:
1. Set threshold = 300ms
2. Verify pause at 300ms
3. Set threshold = 800ms
4. Verify pause at 800ms

**Expected Results**:
- [ ] 300ms threshold works
- [ ] 800ms threshold works
- [ ] Configuration persisted
- [ ] Real-time adjustment works

---

### Test Case IT-STT-005-02: Pause During Slow Speech

**Objective**: Verify pause detection with slow speaker.

**Test Steps**:
1. Feed slow speech (long word gaps)
2. Monitor pause detection
3. Verify no false positives

**Expected Results**:
- [ ] Word gaps not treated as pause
- [ ] Sentence completion detected
- [ ] Natural speech flow maintained
- [ ] Accuracy maintained

---

### Test Case IT-STT-005-03: Pause at End of Audio Stream

**Objective**: Verify pause detected when stream ends.

**Test Steps**:
1. Feed audio sample
2. Stop feeding (simulate mic stop)
3. Verify pause triggered

**Expected Results**:
- [ ] End of stream detected
- [ ] Final pause callback triggered
- [ ] Result finalized
- [ ] No hanging state

---

### Test Case IT-STT-005-04: Pause and Translation Coordination

**Objective**: Verify pause triggers translation.

**Test Steps**:
1. Configure pause threshold
2. Feed speech with natural pause
3. Verify translation called
4. Verify timing

**Expected Results**:
- [ ] Translation called on pause
- [ ] Correct text passed
- [ ] No double translation
- [ ] Latency minimized

---

## WF-STT-006: Speaker Diarization

### Test Case IT-STT-006-01: Two-Speaker Separation

**Objective**: Verify diarization separates two speakers.

**Test Steps**:
1. Enable diarization
2. Feed audio with two speakers
3. Verify speaker labels assigned

**Expected Results**:
- [ ] Speaker A segments identified
- [ ] Speaker B segments identified
- [ ] No segment misattribution > 5%
- [ ] Overlap handled gracefully

```swift
func testTwoSpeakerDiarization() async throws {
    let diarizer = SpeakerDiarizer()
    diarizer.enable()

    let result = try await diarizer.process(audio: "two_speakers.wav")

    XCTAssertEqual(result.speakerCount, 2)
    XCTAssertGreaterThan(result.segments.filter { $0.speaker == 0 }.count, 0)
    XCTAssertGreaterThan(result.segments.filter { $0.speaker == 1 }.count, 0)
}
```

---

### Test Case IT-STT-006-02: Speaker Profile Matching

**Objective**: Verify speakers matched to profiles.

**Test Steps**:
1. Create speaker profiles
2. Process new audio
3. Match to existing profiles

**Expected Results**:
- [ ] Known speaker identified
- [ ] Profile match confidence > 90%
- [ ] Unknown speaker flagged
- [ ] Profile update available

---

### Test Case IT-STT-006-03: Diarization with Overlapping Speech

**Objective**: Verify handling of simultaneous speech.

**Test Steps**:
1. Feed audio with 2-second overlap
2. Process diarization
3. Verify overlap handling

**Expected Results**:
- [ ] Overlap detected
- [ ] Dominant speaker prioritized
- [ ] Both segments captured
- [ ] Warning logged

---

### Test Case IT-STT-006-04: Diarization Latency

**Objective**: Verify diarization doesn't add excessive latency.

**Test Steps**:
1. Measure STT latency without diarization
2. Enable diarization
3. Measure total latency
4. Calculate overhead

**Expected Results**:
- [ ] Diarization overhead < 50ms
- [ ] Total latency still acceptable
- [ ] No visible delay to user
- [ ] Performance consistent

---

### Test Case IT-STT-006-05: Single Speaker Mode Optimization

**Objective**: Verify diarization disabled in single mode.

**Test Steps**:
1. Enable single speaker mode
2. Verify diarization not running
3. Check resource usage

**Expected Results**:
- [ ] Diarization bypassed
- [ ] Lower CPU usage
- [ ] Lower latency
- [ ] Seamless mode switch

---

## WF-STT-007: WhisperKit Fallback

### Test Case IT-STT-007-01: Fallback Trigger Conditions

**Objective**: Verify WhisperKit activated on SF failure.

**Test Steps**:
1. Simulate SFSpeechRecognizer unavailable
2. Verify WhisperKit activation
3. Process audio with WhisperKit

**Expected Results**:
- [ ] Fallback triggered automatically
- [ ] User notified of offline mode
- [ ] Audio processed successfully
- [ ] Quality acceptable

```swift
func testWhisperKitFallback() async throws {
    let manager = SpeechRecognitionManager()
    manager.mockSFRecognizer.isAvailable = false

    try await manager.startRecognition()

    XCTAssertTrue(manager.isUsingFallback)
    XCTAssertEqual(manager.activeEngine, .whisperKit)

    feedAudioSample("test_speech.wav")
    let result = await manager.getResult()

    XCTAssertNotNil(result)
}
```

---

### Test Case IT-STT-007-02: WhisperKit Model Loading

**Objective**: Verify model loads efficiently.

**Test Steps**:
1. Ensure model not in memory
2. Trigger WhisperKit activation
3. Measure model load time

**Expected Results**:
- [ ] Model loads < 3 seconds
- [ ] Memory increase tracked
- [ ] Model cached for next use
- [ ] Loading indicator shown

---

### Test Case IT-STT-007-03: WhisperKit Accuracy

**Objective**: Verify WhisperKit accuracy meets threshold.

**Test Steps**:
1. Process standard test audio
2. Compare to known transcription
3. Calculate WER (Word Error Rate)

**Expected Results**:
- [ ] WER < 15% for clean audio
- [ ] WER < 30% for noisy audio
- [ ] Japanese accuracy acceptable
- [ ] English accuracy acceptable

---

### Test Case IT-STT-007-04: Return to SFSpeechRecognizer

**Objective**: Verify return to primary when available.

**Test Steps**:
1. Start in fallback mode
2. Make SFSpeechRecognizer available
3. Verify switch back

**Expected Results**:
- [ ] Availability detected
- [ ] Smooth transition
- [ ] User notified
- [ ] No audio disruption

---

### Test Case IT-STT-007-05: WhisperKit Resource Usage

**Objective**: Verify fallback resource consumption.

**Test Steps**:
1. Measure baseline resources
2. Activate WhisperKit
3. Process 1 minute of audio
4. Measure resources

**Expected Results**:
- [ ] Memory increase < 500MB
- [ ] CPU usage < 60%
- [ ] Battery drain acceptable
- [ ] Device temperature stable

---

## WF-STT-008: Language Auto-Detection

### Test Case IT-STT-008-01: Japanese Detection

**Objective**: Verify Japanese speech correctly identified.

**Test Steps**:
1. Enable auto-detection
2. Feed Japanese audio
3. Verify detected language

**Expected Results**:
- [ ] Language = Japanese
- [ ] Confidence > 90%
- [ ] Detection < 2 seconds
- [ ] Recognizer configured accordingly

---

### Test Case IT-STT-008-02: English Detection

**Objective**: Verify English speech correctly identified.

**Test Steps**:
1. Enable auto-detection
2. Feed English audio
3. Verify detected language

**Expected Results**:
- [ ] Language = English
- [ ] Confidence > 90%
- [ ] Detection < 2 seconds
- [ ] Recognizer configured accordingly

---

### Test Case IT-STT-008-03: Language Switch Mid-Session

**Objective**: Verify language change detected mid-session.

**Test Steps**:
1. Start with Japanese
2. Switch to English (same speaker)
3. Verify detection and adaptation

**Expected Results**:
- [ ] Switch detected within 3 seconds
- [ ] Recognizer reconfigured
- [ ] Transcription accurate post-switch
- [ ] No lost audio

---

### Test Case IT-STT-008-04: Ambiguous Language Handling

**Objective**: Verify handling of mixed-language speech.

**Test Steps**:
1. Feed code-switched audio (Japanese + English)
2. Observe detection behavior

**Expected Results**:
- [ ] Dominant language detected
- [ ] Confidence appropriately low
- [ ] Graceful degradation
- [ ] User can override

---

### Test Case IT-STT-008-05: Detection Fallback

**Objective**: Verify fallback when detection fails.

**Test Steps**:
1. Feed unclear audio
2. Detection confidence low
3. Verify fallback to user setting

**Expected Results**:
- [ ] Low confidence logged
- [ ] User's default language used
- [ ] User prompted if repeated failure
- [ ] System remains functional

---

## End-to-End STT Scenarios

### Test Case IT-STT-E2E-01: 5-Minute Recognition Session

**Objective**: Verify stability over extended session.

**Test Steps**:
1. Start recognition
2. Feed 5 minutes of varied audio
3. Monitor throughout
4. Stop and verify

**Expected Results**:
- [ ] All audio processed
- [ ] Memory stable
- [ ] No accuracy degradation
- [ ] No crashes or freezes

---

### Test Case IT-STT-E2E-02: Recognition Under Battery Stress

**Objective**: Verify recognition quality at low battery.

**Test Steps**:
1. Drain battery to 15%
2. Start recognition
3. Process audio samples
4. Compare accuracy to normal

**Expected Results**:
- [ ] Recognition functional
- [ ] May use efficient mode
- [ ] Accuracy within acceptable range
- [ ] Battery warning handled

---

### Test Case IT-STT-E2E-03: Audio Session Interruption Recovery

**Objective**: Verify recovery from audio interruption.

**Test Steps**:
1. Start recognition
2. Trigger phone call (interruption)
3. End call
4. Resume recognition

**Expected Results**:
- [ ] Recognition paused during call
- [ ] Resume after call
- [ ] No data loss
- [ ] Audio session reconfigured

---

## Test Data Fixtures

### Audio Samples

| Sample ID | Language | Duration | Content | Speaker | Noise Level |
|-----------|----------|----------|---------|---------|-------------|
| `ja_clear_01.wav` | Japanese | 5s | Greeting | Female | Clean |
| `ja_noisy_01.wav` | Japanese | 5s | Same | Female | Café ambient |
| `en_clear_01.wav` | English | 5s | Greeting | Male | Clean |
| `en_fast_01.wav` | English | 5s | Fast speech | Male | Clean |
| `mixed_01.wav` | JA+EN | 10s | Code-switch | Female | Clean |
| `two_speakers_01.wav` | English | 20s | Conversation | M+F | Clean |

### Expected Transcriptions

| Sample ID | Expected Text | Acceptable WER |
|-----------|---------------|----------------|
| `ja_clear_01.wav` | "こんにちは、今日はお元気ですか" | < 5% |
| `ja_noisy_01.wav` | "こんにちは、今日はお元気ですか" | < 15% |
| `en_clear_01.wav` | "Hello, how are you today" | < 5% |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 52 test cases | AI Agent |
