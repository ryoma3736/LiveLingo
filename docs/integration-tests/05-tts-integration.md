# IT-TTS: Text-to-Speech Integration Tests

## Overview

This document defines integration tests for the Text-to-Speech (TTS) subsystem based on workflows WF-TTS-001 through WF-TTS-005. These tests verify speech synthesis quality, provider integration, and audio playback.

**Priority**: P0-Critical
**Total Test Cases**: 35
**Estimated Execution Time**: 12 minutes

---

## Test Environment

### Required Components
- `TTSManager`
- `AVSpeechSynthesizer`
- `CoeFontAPIClient`
- `PersonalVoiceManager`
- `AudioQueueManager`
- `AVAudioPlayer`

### Mock Dependencies
- `MockAVSpeechSynthesizer`
- `MockCoeFontAPI`
- `MockAudioSession`
- `MockAudioPlayer`

### Test Data
- Text samples in multiple languages
- Expected audio characteristics
- Voice configuration presets

---

## WF-TTS-001: AVSpeechSynthesizer

### Test Case IT-TTS-001-01: Basic System TTS

**Objective**: Verify AVSpeechSynthesizer produces audio output.

**Preconditions**:
- Audio session configured for playback
- System volume > 0
- Speaker available

**Test Steps**:
1. Initialize AVSpeechSynthesizer
2. Create utterance with English text
3. Speak utterance
4. Verify audio output

**Expected Results**:
- [ ] Speech synthesis starts within 100ms
- [ ] Audio audible through speaker
- [ ] Completion callback received
- [ ] No audio artifacts

```swift
func testAVSpeechSynthesizerBasic() async throws {
    let tts = TTSManager()
    tts.provider = .system

    let expectation = expectation(description: "Speech completed")
    tts.onCompletion = {
        expectation.fulfill()
    }

    try await tts.speak(text: "Hello, how are you?", language: .english)

    await fulfillment(of: [expectation], timeout: 5.0)
}
```

---

### Test Case IT-TTS-001-02: Voice Selection

**Objective**: Verify correct voice selected for language.

**Test Steps**:
1. Request Japanese voice
2. Verify Kyoko or equivalent selected
3. Request English voice
4. Verify appropriate voice selected

**Expected Results**:
- [ ] Japanese: Kyoko/O-Ren selected
- [ ] English: Samantha/Alex selected
- [ ] Voice matches gender preference
- [ ] Quality matches settings

---

### Test Case IT-TTS-001-03: Speech Rate Configuration

**Objective**: Verify speech rate applied correctly.

**Test Steps**:
1. Set rate = 0.5 (slow)
2. Speak and measure duration
3. Set rate = 1.0 (normal)
4. Speak and measure duration
5. Set rate = 1.5 (fast)
6. Speak and measure duration

**Expected Results**:
- [ ] Slow rate ~2x normal duration
- [ ] Fast rate ~0.67x normal duration
- [ ] Audio quality maintained
- [ ] Rate persisted in settings

---

### Test Case IT-TTS-001-04: Pitch Adjustment

**Objective**: Verify pitch multiplier works.

**Test Steps**:
1. Set pitch = 0.8 (lower)
2. Speak text
3. Set pitch = 1.2 (higher)
4. Speak text
5. Verify audible difference

**Expected Results**:
- [ ] Lower pitch audible
- [ ] Higher pitch audible
- [ ] No distortion
- [ ] Natural sounding

---

### Test Case IT-TTS-001-05: Speech Interruption

**Objective**: Verify current speech can be interrupted.

**Test Steps**:
1. Start speaking long text
2. Interrupt at 50% progress
3. Start new utterance

**Expected Results**:
- [ ] Previous speech stops immediately
- [ ] New speech starts
- [ ] No audio overlap
- [ ] Clean transition

---

### Test Case IT-TTS-001-06: Queue Multiple Utterances

**Objective**: Verify utterance queue processed sequentially.

**Test Steps**:
1. Queue 3 utterances
2. Verify sequential playback
3. Track completion order

**Expected Results**:
- [ ] Utterances play in order
- [ ] No gap between utterances
- [ ] All completions received
- [ ] Queue manageable

```swift
func testUtteranceQueue() async throws {
    let tts = TTSManager()

    var completionOrder: [Int] = []
    tts.onUtteranceComplete = { index in
        completionOrder.append(index)
    }

    tts.queue(text: "First", language: .english, id: 1)
    tts.queue(text: "Second", language: .english, id: 2)
    tts.queue(text: "Third", language: .english, id: 3)

    try await tts.processQueue()

    XCTAssertEqual(completionOrder, [1, 2, 3])
}
```

---

### Test Case IT-TTS-001-07: Pause and Resume Speech

**Objective**: Verify speech can be paused and resumed.

**Test Steps**:
1. Start speaking
2. Pause at midpoint
3. Resume
4. Verify completion

**Expected Results**:
- [ ] Pause immediate
- [ ] Resume from pause point
- [ ] No audio glitch
- [ ] Completion received

---

## WF-TTS-002: CoeFont API Integration

### Test Case IT-TTS-002-01: CoeFont API Request

**Objective**: Verify CoeFont API call structure.

**Preconditions**:
- Valid CoeFont API key
- Network available

**Test Steps**:
1. Initialize CoeFontClient
2. Create synthesis request
3. Send to API
4. Parse audio response

**Expected Results**:
- [ ] HMAC-SHA256 signature correct
- [ ] API returns 200 OK
- [ ] Audio data received
- [ ] Format = wav or mp3

```swift
func testCoeFontAPIRequest() async throws {
    let client = CoeFontAPIClient(
        accessKey: testAccessKey,
        clientSecret: testClientSecret
    )

    let audioData = try await client.synthesize(
        text: "こんにちは",
        coefontId: "test-voice-id",
        format: .wav
    )

    XCTAssertGreaterThan(audioData.count, 1000)
    XCTAssertTrue(audioData.starts(with: [0x52, 0x49, 0x46, 0x46])) // RIFF header
}
```

---

### Test Case IT-TTS-002-02: CoeFont HMAC Authentication

**Objective**: Verify HMAC-SHA256 signature generation.

**Test Steps**:
1. Create request with known values
2. Generate signature
3. Compare to expected

**Expected Results**:
- [ ] Signature matches expected
- [ ] Timestamp included
- [ ] Request body hashed
- [ ] Authentication header correct

---

### Test Case IT-TTS-002-03: CoeFont Voice Selection

**Objective**: Verify voice ID selection for different speakers.

**Test Steps**:
1. Select female Japanese voice
2. Select male English voice
3. Verify API calls with correct IDs

**Expected Results**:
- [ ] Female voice ID used
- [ ] Male voice ID used
- [ ] Voice mapping configurable
- [ ] Custom voices supported

---

### Test Case IT-TTS-002-04: CoeFont Error Handling

**Objective**: Verify graceful handling of API errors.

**Test Steps**:
1. Simulate 401 Unauthorized
2. Simulate 429 Rate Limited
3. Simulate 500 Server Error
4. Verify fallback behavior

**Expected Results**:
- [ ] 401: Re-authenticate or notify
- [ ] 429: Retry with backoff
- [ ] 500: Fallback to system TTS
- [ ] User notified appropriately

---

### Test Case IT-TTS-002-05: CoeFont Streaming Audio

**Objective**: Verify streaming audio playback.

**Test Steps**:
1. Request long text synthesis
2. Start playback on first chunk
3. Continue streaming
4. Verify seamless playback

**Expected Results**:
- [ ] Playback starts before full download
- [ ] No gaps in audio
- [ ] Buffer management correct
- [ ] Reduced latency vs full download

---

### Test Case IT-TTS-002-06: CoeFont Offline Fallback

**Objective**: Verify fallback when CoeFont unavailable.

**Test Steps**:
1. Disable network
2. Request CoeFont synthesis
3. Verify system TTS fallback

**Expected Results**:
- [ ] Network failure detected
- [ ] System TTS activated
- [ ] User notified of quality change
- [ ] Speech still produced

---

## WF-TTS-003: Personal Voice (iOS 17+)

### Test Case IT-TTS-003-01: Personal Voice Availability Check

**Objective**: Verify Personal Voice availability detection.

**Preconditions**:
- iOS 17.0+
- Personal Voice configured on device

**Test Steps**:
1. Check Personal Voice availability
2. List available Personal Voices
3. Handle unavailable case

**Expected Results**:
- [ ] Availability correctly detected
- [ ] Available voices listed
- [ ] Graceful handling if none
- [ ] iOS 16 fallback works

```swift
func testPersonalVoiceAvailability() async throws {
    let manager = PersonalVoiceManager()

    if #available(iOS 17.0, *) {
        let isAvailable = await manager.checkAvailability()

        if isAvailable {
            let voices = await manager.listPersonalVoices()
            XCTAssertGreaterThan(voices.count, 0)
        } else {
            // No Personal Voice configured - acceptable
            XCTAssertTrue(true)
        }
    } else {
        // iOS 16 or earlier - feature not available
        XCTAssertFalse(manager.isSupported)
    }
}
```

---

### Test Case IT-TTS-003-02: Personal Voice Authorization

**Objective**: Verify Personal Voice authorization flow.

**Test Steps**:
1. Request Personal Voice access
2. Handle authorization response
3. Store authorization state

**Expected Results**:
- [ ] Authorization prompt shown
- [ ] Grant: voices accessible
- [ ] Deny: fallback to system
- [ ] State persisted

---

### Test Case IT-TTS-003-03: Personal Voice Synthesis

**Objective**: Verify synthesis with Personal Voice.

**Test Steps**:
1. Select user's Personal Voice
2. Synthesize text
3. Verify audio quality

**Expected Results**:
- [ ] Voice sounds like user
- [ ] Quality acceptable
- [ ] Latency reasonable
- [ ] Works offline

---

### Test Case IT-TTS-003-04: Personal Voice Not Configured

**Objective**: Verify handling when no Personal Voice exists.

**Test Steps**:
1. Clear Personal Voices (test only)
2. Request Personal Voice
3. Verify fallback

**Expected Results**:
- [ ] Graceful fallback
- [ ] User prompted to create
- [ ] System TTS used instead
- [ ] No crash or error

---

## WF-TTS-004: Audio Streaming Queue

### Test Case IT-TTS-004-01: Buffer Ahead (2 Segments)

**Objective**: Verify buffer ahead strategy works.

**Test Steps**:
1. Configure bufferAheadCount = 2
2. Queue 5 segments
3. Verify buffer behavior

**Expected Results**:
- [ ] First 2 segments pre-loaded
- [ ] Playback seamless
- [ ] Memory bounded
- [ ] Buffer refilled automatically

```swift
func testBufferAhead() async throws {
    let queue = AudioQueueManager()
    queue.bufferAheadCount = 2

    var bufferLoadEvents: [Int] = []
    queue.onSegmentLoaded = { index in
        bufferLoadEvents.append(index)
    }

    queue.enqueue(segments: [seg1, seg2, seg3, seg4, seg5])

    // Initially segments 0,1 should be buffered
    XCTAssertEqual(bufferLoadEvents, [0, 1])

    // After playing segment 0
    await queue.playNext()
    // Segment 2 should now be buffered
    XCTAssertTrue(bufferLoadEvents.contains(2))
}
```

---

### Test Case IT-TTS-004-02: Queue Playback Continuity

**Objective**: Verify no gaps between queued segments.

**Test Steps**:
1. Queue multiple audio segments
2. Play all
3. Measure inter-segment gaps

**Expected Results**:
- [ ] Gaps < 50ms
- [ ] Seamless perception
- [ ] No clicks or pops
- [ ] Consistent timing

---

### Test Case IT-TTS-004-03: Queue Interruption

**Objective**: Verify queue can be cleared during playback.

**Test Steps**:
1. Queue 5 segments
2. Play segment 1
3. Clear queue
4. Verify cleanup

**Expected Results**:
- [ ] Current segment stops
- [ ] Queue cleared
- [ ] Buffers released
- [ ] Ready for new queue

---

### Test Case IT-TTS-004-04: Low Memory Queue Behavior

**Objective**: Verify queue degrades gracefully under memory pressure.

**Test Steps**:
1. Trigger memory warning
2. Observe buffer reduction
3. Verify playback continues

**Expected Results**:
- [ ] Buffer ahead reduced to 1
- [ ] Playback continues
- [ ] Quality maintained
- [ ] Recovery when pressure ends

---

## WF-TTS-005: Voice Selection

### Test Case IT-TTS-005-01: Voice List Loading

**Objective**: Verify available voices loaded correctly.

**Test Steps**:
1. Request voice list for Japanese
2. Request voice list for English
3. Verify voice metadata

**Expected Results**:
- [ ] Japanese voices include Kyoko, O-Ren
- [ ] English voices include Samantha, Alex
- [ ] Gender info available
- [ ] Quality level indicated

---

### Test Case IT-TTS-005-02: Voice Preference Persistence

**Objective**: Verify voice preferences saved and restored.

**Test Steps**:
1. Select specific voice
2. Restart app
3. Verify same voice active

**Expected Results**:
- [ ] Preference saved to UserDefaults
- [ ] Restored on launch
- [ ] Fallback if voice removed
- [ ] Sync across devices (if enabled)

---

### Test Case IT-TTS-005-03: Voice Download (Enhanced)

**Objective**: Verify enhanced voice download flow.

**Test Steps**:
1. Check for enhanced voice
2. Trigger download
3. Monitor progress
4. Use after download

**Expected Results**:
- [ ] Download status shown
- [ ] Progress trackable
- [ ] Voice usable after download
- [ ] Quality improvement audible

---

### Test Case IT-TTS-005-04: Voice Gender Matching

**Objective**: Verify voice gender matches speaker.

**Test Steps**:
1. Configure dual speaker mode
2. Set Speaker A = female
3. Set Speaker B = male
4. Verify voice assignments

**Expected Results**:
- [ ] Speaker A gets female voice
- [ ] Speaker B gets male voice
- [ ] Distinguishable audio
- [ ] Configurable per speaker

---

### Test Case IT-TTS-005-05: Voice Language Fallback

**Objective**: Verify fallback when language not supported.

**Test Steps**:
1. Request voice for rare language
2. Observe fallback behavior

**Expected Results**:
- [ ] Fallback to closest match
- [ ] User notified
- [ ] Some output produced
- [ ] No crash

---

## Audio Session Integration

### Test Case IT-TTS-AUD-01: Audio Session for Playback

**Objective**: Verify audio session configured for TTS playback.

**Test Steps**:
1. Configure audio session
2. Start TTS playback
3. Verify session settings

**Expected Results**:
- [ ] Category = playback or playAndRecord
- [ ] Mode = voiceChat or default
- [ ] Route to speaker
- [ ] Volume controllable

---

### Test Case IT-TTS-AUD-02: Mix with Other Audio

**Objective**: Verify TTS mixes with background audio appropriately.

**Test Steps**:
1. Play background music
2. Start TTS
3. Verify audio behavior

**Expected Results**:
- [ ] TTS audible
- [ ] Music ducked or paused
- [ ] Music resumes after TTS
- [ ] User preference respected

---

### Test Case IT-TTS-AUD-03: Bluetooth Audio Output

**Objective**: Verify TTS plays through Bluetooth.

**Test Steps**:
1. Connect Bluetooth speaker
2. Start TTS
3. Verify output route

**Expected Results**:
- [ ] Audio routes to Bluetooth
- [ ] Quality acceptable
- [ ] Latency manageable
- [ ] Route change handled

---

## TTS Performance

### Test Case IT-TTS-PERF-01: Synthesis Latency

**Objective**: Measure time from text to audio start.

**Test Steps**:
1. Measure system TTS latency
2. Measure CoeFont latency
3. Compare to targets

**Expected Results**:
- [ ] System TTS < 100ms
- [ ] CoeFont < 500ms (network)
- [ ] Consistent performance
- [ ] Metrics logged

---

### Test Case IT-TTS-PERF-02: Memory Usage

**Objective**: Verify TTS memory footprint.

**Test Steps**:
1. Baseline memory
2. Synthesize 5 minutes of speech
3. Measure peak memory
4. Verify cleanup

**Expected Results**:
- [ ] Peak < 100MB additional
- [ ] Cleanup after playback
- [ ] No memory leak
- [ ] Buffer pool efficient

---

### Test Case IT-TTS-PERF-03: Battery Impact

**Objective**: Verify TTS battery consumption.

**Test Steps**:
1. Run 30-minute TTS session
2. Monitor battery drain
3. Compare providers

**Expected Results**:
- [ ] System TTS: minimal impact
- [ ] CoeFont: network + audio
- [ ] Within acceptable range
- [ ] User configurable trade-off

---

## Test Data Fixtures

### Text Samples

| ID | Language | Text | Expected Duration |
|----|----------|------|-------------------|
| `en_short_01` | English | "Hello" | ~0.5s |
| `en_long_01` | English | (Paragraph) | ~30s |
| `ja_short_01` | Japanese | "こんにちは" | ~1s |
| `ja_long_01` | Japanese | (Paragraph) | ~30s |

### Voice Configurations

| Language | Gender | System Voice | CoeFont ID |
|----------|--------|--------------|------------|
| English | Female | Samantha | cf-en-f-01 |
| English | Male | Alex | cf-en-m-01 |
| Japanese | Female | Kyoko | cf-ja-f-01 |
| Japanese | Male | Otoya | cf-ja-m-01 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 35 test cases | AI Agent |
