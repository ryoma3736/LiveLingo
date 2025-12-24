# IT-AUD: Audio Session Integration Tests

## Overview

This document defines integration tests for audio session management based on workflows WF-AUD-001 through WF-AUD-006. These tests verify proper audio configuration, interruption handling, and device routing.

**Priority**: P1-High
**Total Test Cases**: 40
**Estimated Execution Time**: 15 minutes

---

## Test Environment

### Required Components
- `AudioSessionManager`
- `AVAudioSession`
- `AVAudioEngine`
- `InterruptionHandler`
- `RouteChangeHandler`

### Mock Dependencies
- `MockAVAudioSession`
- `MockNotificationCenter`
- `MockAudioRoute`

### Hardware Requirements
- iPhone with speaker
- Headphones (wired/Bluetooth)
- External Bluetooth speaker (optional)

---

## WF-AUD-001: Audio Session Configuration

### Test Case IT-AUD-001-01: PlayAndRecord Category Setup

**Objective**: Verify audio session configured for simultaneous input/output.

**Preconditions**:
- No other audio-active apps
- Microphone permission granted

**Test Steps**:
1. Configure audio session
2. Set category to playAndRecord
3. Set mode to voiceChat
4. Activate session

**Expected Results**:
- [ ] Category = .playAndRecord
- [ ] Mode = .voiceChat
- [ ] Session activated successfully
- [ ] Both input and output available

```swift
func testAudioSessionConfiguration() throws {
    let manager = AudioSessionManager()

    try manager.configure(
        category: .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth]
    )

    let session = AVAudioSession.sharedInstance()
    XCTAssertEqual(session.category, .playAndRecord)
    XCTAssertEqual(session.mode, .voiceChat)
    XCTAssertTrue(session.categoryOptions.contains(.defaultToSpeaker))
}
```

---

### Test Case IT-AUD-001-02: Sample Rate Configuration

**Objective**: Verify sample rate set correctly.

**Test Steps**:
1. Set preferred sample rate = 16000 Hz
2. Activate session
3. Verify actual sample rate

**Expected Results**:
- [ ] Preferred rate set
- [ ] Actual rate = 16000 or acceptable (44100, 48000)
- [ ] Audio engine configured accordingly
- [ ] No sample rate mismatch errors

---

### Test Case IT-AUD-001-03: Buffer Duration Configuration

**Objective**: Verify buffer duration set for low latency.

**Test Steps**:
1. Set preferred buffer duration = 0.005 (5ms)
2. Activate session
3. Verify actual buffer duration

**Expected Results**:
- [ ] Preferred duration set
- [ ] Actual duration ≤ 10ms
- [ ] Low latency achievable
- [ ] No buffer underruns

---

### Test Case IT-AUD-001-04: Session Activation Failure

**Objective**: Verify graceful handling of activation failure.

**Test Steps**:
1. Simulate audio session conflict
2. Attempt activation
3. Verify error handling

**Expected Results**:
- [ ] Error thrown
- [ ] User-friendly message
- [ ] Retry available
- [ ] State consistent

---

### Test Case IT-AUD-001-05: Deactivation and Cleanup

**Objective**: Verify proper session deactivation.

**Test Steps**:
1. Activate session
2. Start audio processing
3. Stop processing
4. Deactivate session

**Expected Results**:
- [ ] Processing stopped before deactivation
- [ ] Session deactivated successfully
- [ ] Resources released
- [ ] Other apps can use audio

---

## WF-AUD-002: Phone Call Interruption

### Test Case IT-AUD-002-01: Incoming Call Interruption

**Objective**: Verify interpretation pauses on phone call.

**Test Steps**:
1. Start interpretation session
2. Receive incoming call
3. Verify interruption handling
4. End call
5. Verify resumption

**Expected Results**:
- [ ] Interpretation paused immediately
- [ ] Audio recording stopped
- [ ] TTS stopped
- [ ] Session state preserved
- [ ] Auto-resume available

```swift
func testPhoneCallInterruption() async throws {
    let manager = AudioSessionManager()
    let interpretation = InterpretationViewModel()

    interpretation.startInterpretation()
    XCTAssertTrue(interpretation.isActive)

    // Simulate phone call interruption
    NotificationCenter.default.post(
        name: AVAudioSession.interruptionNotification,
        object: nil,
        userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue,
            AVAudioSessionInterruptionReasonKey: AVAudioSession.InterruptionReason.default.rawValue
        ]
    )

    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertTrue(interpretation.isPaused)
    XCTAssertFalse(interpretation.isRecording)

    // Simulate call ended
    NotificationCenter.default.post(
        name: AVAudioSession.interruptionNotification,
        object: nil,
        userInfo: [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
    )

    try await Task.sleep(nanoseconds: 100_000_000)
    // Should prompt or auto-resume based on settings
}
```

---

### Test Case IT-AUD-002-02: Outgoing Call Handling

**Objective**: Verify handling when user makes a call.

**Test Steps**:
1. Start interpretation
2. User initiates phone call
3. Verify interpretation state

**Expected Results**:
- [ ] Interpretation paused
- [ ] State saved
- [ ] No interference with call
- [ ] Ready to resume after

---

### Test Case IT-AUD-002-03: Call Declined Without Answer

**Objective**: Verify quick recovery when call rejected.

**Test Steps**:
1. Start interpretation
2. Receive call
3. Decline call immediately
4. Verify recovery

**Expected Results**:
- [ ] Brief pause only
- [ ] Auto-resume after decline
- [ ] Minimal disruption
- [ ] No state loss

---

### Test Case IT-AUD-002-04: Multiple Interruptions

**Objective**: Verify handling of back-to-back interruptions.

**Test Steps**:
1. Start interpretation
2. First call interruption
3. End first call
4. Second call interruption
5. End second call

**Expected Results**:
- [ ] All interruptions handled
- [ ] State preserved throughout
- [ ] Final resume successful
- [ ] No accumulated errors

---

## WF-AUD-003: Siri Interruption

### Test Case IT-AUD-003-01: Hey Siri Activation

**Objective**: Verify handling of Siri activation.

**Test Steps**:
1. Start interpretation
2. Say "Hey Siri"
3. Observe interruption
4. Complete Siri interaction
5. Verify recovery

**Expected Results**:
- [ ] Interpretation paused
- [ ] Microphone released to Siri
- [ ] No audio conflict
- [ ] Resume after Siri dismissal

---

### Test Case IT-AUD-003-02: Siri Button Activation

**Objective**: Verify handling of manual Siri activation.

**Test Steps**:
1. Start interpretation
2. Long-press side button for Siri
3. Cancel Siri
4. Verify recovery

**Expected Results**:
- [ ] Same handling as voice activation
- [ ] Quick recovery on cancel
- [ ] State preserved
- [ ] No lingering audio issues

---

### Test Case IT-AUD-003-03: Siri with Audio Response

**Objective**: Verify handling when Siri speaks response.

**Test Steps**:
1. Start interpretation
2. Activate Siri
3. Ask question (Siri speaks answer)
4. Wait for Siri to finish
5. Verify recovery

**Expected Results**:
- [ ] Interpretation paused throughout
- [ ] Siri audio not captured as speech
- [ ] Clean resume after Siri done
- [ ] No false recognition

---

## WF-AUD-004: Route Change Handling

### Test Case IT-AUD-004-01: Bluetooth Headphones Connect

**Objective**: Verify audio routes to new Bluetooth device.

**Test Steps**:
1. Start interpretation with built-in speaker
2. Connect Bluetooth headphones
3. Verify audio routing

**Expected Results**:
- [ ] Route change detected
- [ ] Output routes to Bluetooth
- [ ] Input may route to Bluetooth mic
- [ ] No audio interruption

```swift
func testBluetoothConnection() async throws {
    let manager = AudioSessionManager()

    var routeChangeReceived = false
    manager.onRouteChange = { reason, previousRoute, currentRoute in
        if reason == .newDeviceAvailable {
            routeChangeReceived = true
        }
    }

    // Simulate Bluetooth connection
    NotificationCenter.default.post(
        name: AVAudioSession.routeChangeNotification,
        object: nil,
        userInfo: [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue
        ]
    )

    try await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertTrue(routeChangeReceived)
}
```

---

### Test Case IT-AUD-004-02: Headphones Disconnect

**Objective**: Verify handling when headphones unplugged.

**Test Steps**:
1. Using interpretation with headphones
2. Unplug headphones
3. Verify audio routing

**Expected Results**:
- [ ] Route change detected
- [ ] Output routes to speaker
- [ ] Pause or volume check (optional)
- [ ] User notified if needed

---

### Test Case IT-AUD-004-03: Multiple Audio Outputs Available

**Objective**: Verify correct output selection with multiple options.

**Test Steps**:
1. Connect Bluetooth speaker
2. Connect wired headphones
3. Start interpretation
4. Verify output priority

**Expected Results**:
- [ ] Most recent device preferred
- [ ] User can override
- [ ] Selection persisted
- [ ] No confusion

---

### Test Case IT-AUD-004-04: CarPlay Connection

**Objective**: Verify audio routing to CarPlay.

**Test Steps**:
1. Start interpretation
2. Connect to CarPlay
3. Verify audio routes correctly

**Expected Results**:
- [ ] Audio routes to car
- [ ] Microphone selection appropriate
- [ ] Integration seamless
- [ ] No audio issues

---

### Test Case IT-AUD-004-05: Route Change During Recording

**Objective**: Verify recording continues through route change.

**Test Steps**:
1. Start recording
2. Connect Bluetooth
3. Verify recording continues
4. Verify no audio gaps

**Expected Results**:
- [ ] Recording uninterrupted
- [ ] Audio input continuous
- [ ] No lost audio data
- [ ] Quality maintained

---

## WF-AUD-005: Media Server Reset

### Test Case IT-AUD-005-01: Media Server Crash Recovery

**Objective**: Verify recovery from media server reset.

**Test Steps**:
1. Start interpretation
2. Simulate media server reset notification
3. Verify recovery

**Expected Results**:
- [ ] Reset detected
- [ ] Audio engine recreated
- [ ] Session reestablished
- [ ] Interpretation resumes

```swift
func testMediaServerReset() async throws {
    let manager = AudioSessionManager()

    var resetHandled = false
    manager.onMediaServicesReset = {
        resetHandled = true
    }

    NotificationCenter.default.post(
        name: AVAudioSession.mediaServicesWereResetNotification,
        object: nil
    )

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertTrue(resetHandled)
    XCTAssertTrue(manager.isSessionActive)
}
```

---

### Test Case IT-AUD-005-02: Media Services Lost

**Objective**: Verify handling of media services lost.

**Test Steps**:
1. Start interpretation
2. Simulate media services lost
3. Verify handling
4. Simulate services restored

**Expected Results**:
- [ ] Lost state detected
- [ ] User notified
- [ ] Graceful pause
- [ ] Recovery on restore

---

### Test Case IT-AUD-005-03: Audio Engine Rebuild

**Objective**: Verify audio engine rebuilt after reset.

**Test Steps**:
1. Build audio engine
2. Simulate reset
3. Verify engine rebuilt
4. Verify tap reinstalled

**Expected Results**:
- [ ] Engine recreated
- [ ] Nodes reconnected
- [ ] Taps reinstalled
- [ ] Audio processing resumes

---

## WF-AUD-006: Device Selection

### Test Case IT-AUD-006-01: Built-in Speaker Selection

**Objective**: Verify selection of built-in speaker.

**Test Steps**:
1. Configure for speaker output
2. Verify port description
3. Play audio

**Expected Results**:
- [ ] Speaker selected
- [ ] Audio plays from device
- [ ] Volume controllable
- [ ] No conflicts

---

### Test Case IT-AUD-006-02: Built-in Microphone Selection

**Objective**: Verify microphone selection.

**Test Steps**:
1. Configure for built-in mic
2. Start recording
3. Verify input source

**Expected Results**:
- [ ] Built-in mic active
- [ ] Audio captured
- [ ] Quality acceptable
- [ ] No feedback

---

### Test Case IT-AUD-006-03: Input Device Switching

**Objective**: Verify switching between input devices.

**Test Steps**:
1. Start with built-in mic
2. Switch to Bluetooth mic
3. Verify switch successful

**Expected Results**:
- [ ] Input switches
- [ ] No audio gap
- [ ] Quality maintained
- [ ] Settings updated

---

### Test Case IT-AUD-006-04: Output Device Switching

**Objective**: Verify switching between output devices.

**Test Steps**:
1. Play through speaker
2. Switch to headphones
3. Switch to Bluetooth

**Expected Results**:
- [ ] Each switch successful
- [ ] No audio interruption
- [ ] Volume appropriate
- [ ] Route updated

---

### Test Case IT-AUD-006-05: Preferred Device Persistence

**Objective**: Verify preferred device saved and restored.

**Test Steps**:
1. Set preferred output to Bluetooth
2. Restart app
3. Connect same Bluetooth
4. Verify auto-selection

**Expected Results**:
- [ ] Preference saved
- [ ] Auto-selected on connect
- [ ] Fallback if unavailable
- [ ] User can override

---

## Audio Quality Tests

### Test Case IT-AUD-QUAL-01: Input Level Monitoring

**Objective**: Verify input level metering works.

**Test Steps**:
1. Start audio session
2. Enable input metering
3. Speak into microphone
4. Verify level changes

**Expected Results**:
- [ ] Level values received
- [ ] Range -60dB to 0dB
- [ ] Updates in real-time
- [ ] Accurate representation

---

### Test Case IT-AUD-QUAL-02: Echo Cancellation

**Objective**: Verify echo cancellation active.

**Test Steps**:
1. Enable speaker output
2. Enable microphone input
3. Play TTS
4. Verify TTS not re-recognized

**Expected Results**:
- [ ] Echo cancellation active
- [ ] TTS output not captured
- [ ] User speech captured
- [ ] Quality maintained

---

### Test Case IT-AUD-QUAL-03: Noise Suppression

**Objective**: Verify noise suppression effectiveness.

**Test Steps**:
1. Enable voice chat mode
2. Add background noise
3. Record speech
4. Verify noise reduction

**Expected Results**:
- [ ] Noise reduced
- [ ] Speech clarity maintained
- [ ] Processing efficient
- [ ] Configurable level

---

## Multi-App Audio

### Test Case IT-AUD-MULTI-01: Music App Ducking

**Objective**: Verify music ducks during interpretation.

**Test Steps**:
1. Play music in Music app
2. Start interpretation
3. Verify music behavior

**Expected Results**:
- [ ] Music volume reduced (ducked)
- [ ] Interpretation audio primary
- [ ] Music resumes after
- [ ] User preference respected

---

### Test Case IT-AUD-MULTI-02: Background Audio App

**Objective**: Verify coexistence with podcast/audiobook.

**Test Steps**:
1. Play podcast in background
2. Start interpretation
3. Verify behavior

**Expected Results**:
- [ ] Interpretation takes priority
- [ ] Podcast paused or ducked
- [ ] Clean audio session sharing
- [ ] No audio glitches

---

### Test Case IT-AUD-MULTI-03: Navigation Audio

**Objective**: Verify handling of navigation interruptions.

**Test Steps**:
1. Start interpretation
2. Receive navigation voice prompt
3. Verify mixing

**Expected Results**:
- [ ] Navigation audio plays
- [ ] Interpretation may pause
- [ ] Resume after navigation
- [ ] No missed turns

---

## Test Data Fixtures

### Audio Session Configurations

| Config ID | Category | Mode | Options |
|-----------|----------|------|---------|
| `default` | playAndRecord | voiceChat | defaultToSpeaker, allowBluetooth |
| `recording` | record | measurement | none |
| `playback` | playback | default | mixWithOthers |

### Interruption Scenarios

| Scenario | Notification | Expected Behavior |
|----------|--------------|-------------------|
| Phone call incoming | began + default | Pause immediately |
| Siri activation | began + default | Pause immediately |
| Timer alert | began + default | Brief pause |
| Call ended | ended + shouldResume | Prompt to resume |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 40 test cases | AI Agent |
