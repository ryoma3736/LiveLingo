# IT-STATE: State Management UI Integration Tests

## Overview

This document defines integration tests for state management and UI synchronization based on the state machines documented in 08-state-management.md. These tests verify correct state transitions, UI updates, and state-driven behavior.

**Priority**: P0-Critical
**Total Test Cases**: 68
**Estimated Execution Time**: 22 minutes

---

## Test Environment

### Required Components
- `AppStateManager`
- `InterpretationStateMachine`
- `AuthStateMachine`
- `AudioSessionStateMachine`
- `NavigationStateMachine`
- All related Views

### Mock Dependencies
- `MockStateObserver`
- `MockTransitionHandler`

### Test Framework
- XCTest with state machine inspection
- XCUITest for UI state verification

---

## IT-STATE-001: Application State Machine Tests

### Test Case IT-STATE-001-01: Cold Start State Sequence

**Objective**: Verify app state transitions on cold start.

**Preconditions**:
- App not running
- User authenticated

**Test Steps**:
1. Launch app
2. Track state transitions
3. Verify final state

**Expected Results**:
- [ ] NotRunning → Launching
- [ ] Launching → CheckingAuth
- [ ] CheckingAuth → Ready
- [ ] Ready → Active (foreground)
- [ ] UI reflects each state

```swift
func testColdStartStateSequence() async throws {
    let stateManager = AppStateManager.shared
    var stateHistory: [AppState] = []

    let cancellable = stateManager.$currentState
        .sink { state in
            stateHistory.append(state)
        }

    await stateManager.performColdStart()

    XCTAssertEqual(stateHistory, [
        .notRunning,
        .launching,
        .checkingAuth,
        .ready,
        .active
    ])

    cancellable.cancel()
}
```

---

### Test Case IT-STATE-001-02: Background Transition

**Objective**: Verify state change when app backgrounds.

**Test Steps**:
1. App in Active state
2. Simulate background event
3. Verify state change

**Expected Results**:
- [ ] Active → Background
- [ ] UI suspends updates
- [ ] Audio session handled
- [ ] State preserved for resume

---

### Test Case IT-STATE-001-03: Foreground Resume

**Objective**: Verify state change when app foregrounds.

**Test Steps**:
1. App in Background state
2. Simulate foreground event
3. Verify state change

**Expected Results**:
- [ ] Background → Active
- [ ] UI resumes updates
- [ ] Audio session restored
- [ ] Previous view state restored

---

### Test Case IT-STATE-001-04: Termination State

**Objective**: Verify cleanup on termination.

**Test Steps**:
1. App in any state
2. Simulate termination
3. Verify cleanup

**Expected Results**:
- [ ] State → Terminating
- [ ] Resources released
- [ ] State persisted
- [ ] No memory leaks

---

## IT-STATE-002: Interpretation State Machine Tests

### Test Case IT-STATE-002-01: Idle to Configuring Transition

**Objective**: Verify interpretation setup transition.

**Test Steps**:
1. State: Idle
2. Tap Start Interpretation
3. Verify state change

**Expected Results**:
- [ ] Idle → Configuring
- [ ] UI shows loading/configuring state
- [ ] Audio session being configured
- [ ] Permissions being verified

```swift
func testIdleToConfiguringTransition() async throws {
    let stateMachine = InterpretationStateMachine()

    XCTAssertEqual(stateMachine.currentState, .idle)

    await stateMachine.start()

    XCTAssertEqual(stateMachine.currentState, .configuring)
}
```

---

### Test Case IT-STATE-002-02: Configuring to Listening Transition

**Objective**: Verify transition to active listening.

**Test Steps**:
1. State: Configuring
2. Configuration complete
3. Verify state change

**Expected Results**:
- [ ] Configuring → Listening
- [ ] Microphone active
- [ ] UI shows listening state
- [ ] Audio level visualization starts

---

### Test Case IT-STATE-002-03: Listening to Recognizing Transition

**Objective**: Verify transition when voice detected.

**Test Steps**:
1. State: Listening
2. Voice activity detected
3. Verify state change

**Expected Results**:
- [ ] Listening → Recognizing
- [ ] STT engine processing
- [ ] Partial results shown
- [ ] Live indicator animating

```swift
func testListeningToRecognizingTransition() async throws {
    let stateMachine = InterpretationStateMachine()
    await stateMachine.start()
    await stateMachine.configurationComplete()

    XCTAssertEqual(stateMachine.currentState, .listening)

    stateMachine.voiceActivityDetected()

    XCTAssertEqual(stateMachine.currentState, .recognizing)
}
```

---

### Test Case IT-STATE-002-04: Recognizing to Translating Transition

**Objective**: Verify transition to translation.

**Test Steps**:
1. State: Recognizing
2. Final STT result received
3. Verify state change

**Expected Results**:
- [ ] Recognizing → Translating
- [ ] Original text displayed
- [ ] Translation API called
- [ ] Loading indicator on translation

---

### Test Case IT-STATE-002-05: Translating to Speaking Transition

**Objective**: Verify transition to TTS.

**Test Steps**:
1. State: Translating
2. Translation complete
3. Verify state change

**Expected Results**:
- [ ] Translating → Speaking
- [ ] Translated text displayed
- [ ] TTS synthesis started
- [ ] Audio output active

---

### Test Case IT-STATE-002-06: Speaking to Listening Transition

**Objective**: Verify cycle completion.

**Test Steps**:
1. State: Speaking
2. TTS complete
3. Verify state change

**Expected Results**:
- [ ] Speaking → Listening
- [ ] Ready for next utterance
- [ ] Transcript bubble complete
- [ ] Audio input resumed

```swift
func testFullInterpretationCycle() async throws {
    let stateMachine = InterpretationStateMachine()
    var stateHistory: [InterpretationState] = []

    let cancellable = stateMachine.$currentState
        .sink { stateHistory.append($0) }

    await stateMachine.start()
    await stateMachine.configurationComplete()
    stateMachine.voiceActivityDetected()
    await stateMachine.sttResultReceived("こんにちは")
    await stateMachine.translationReceived("Hello")
    await stateMachine.ttsSynthesisComplete()

    XCTAssertEqual(stateHistory, [
        .idle,
        .configuring,
        .listening,
        .recognizing,
        .translating,
        .speaking,
        .listening
    ])

    cancellable.cancel()
}
```

---

### Test Case IT-STATE-002-07: Pause State Handling

**Objective**: Verify pause during interpretation.

**Test Steps**:
1. Any active state
2. Tap pause
3. Verify state change

**Expected Results**:
- [ ] Current state → Paused
- [ ] Audio input suspended
- [ ] UI shows paused state
- [ ] Resume available

---

### Test Case IT-STATE-002-08: Stop from Any State

**Objective**: Verify stop works from any state.

**Test Steps**:
1. Various active states
2. Tap stop
3. Verify state change

**Expected Results**:
- [ ] Any state → Idle
- [ ] Resources released
- [ ] Summary or save prompt
- [ ] Clean return to home

---

### Test Case IT-STATE-002-09: Error State Recovery

**Objective**: Verify error handling in state machine.

**Test Steps**:
1. Any state
2. Error occurs
3. Verify recovery

**Expected Results**:
- [ ] Any state → Error
- [ ] Error displayed
- [ ] Recovery options shown
- [ ] Can retry or exit

---

## IT-STATE-003: Authentication State Machine Tests

### Test Case IT-STATE-003-01: Unknown to Checking Transition

**Objective**: Verify auth check on launch.

**Test Steps**:
1. App launches
2. Auth state checked
3. Verify transition

**Expected Results**:
- [ ] Unknown → Checking
- [ ] Keychain accessed
- [ ] Token validated
- [ ] UI shows loading

```swift
func testUnknownToCheckingTransition() async throws {
    let authStateMachine = AuthStateMachine()

    XCTAssertEqual(authStateMachine.currentState, .unknown)

    await authStateMachine.checkAuth()

    XCTAssertTrue([.checking, .signedIn, .signedOut].contains(authStateMachine.currentState))
}
```

---

### Test Case IT-STATE-003-02: Checking to SignedIn Transition

**Objective**: Verify successful auth detection.

**Test Steps**:
1. State: Checking
2. Valid token found
3. Verify state

**Expected Results**:
- [ ] Checking → SignedIn
- [ ] User data loaded
- [ ] UI shows authenticated state
- [ ] Protected features available

---

### Test Case IT-STATE-003-03: Checking to SignedOut Transition

**Objective**: Verify no-auth detection.

**Test Steps**:
1. State: Checking
2. No valid token
3. Verify state

**Expected Results**:
- [ ] Checking → SignedOut
- [ ] Sign in prompt available
- [ ] Limited features mode
- [ ] Data local only

---

### Test Case IT-STATE-003-04: SignedIn to BiometricChallenge Transition

**Objective**: Verify biometric lock.

**Test Steps**:
1. State: SignedIn
2. App backgrounds then foregrounds
3. Biometric required
4. Verify state

**Expected Results**:
- [ ] SignedIn → BiometricChallenge
- [ ] UI shows biometric prompt
- [ ] App content hidden
- [ ] Success returns to SignedIn

---

### Test Case IT-STATE-003-05: BiometricChallenge Success

**Objective**: Verify biometric unlock.

**Test Steps**:
1. State: BiometricChallenge
2. Biometric success
3. Verify state

**Expected Results**:
- [ ] BiometricChallenge → SignedIn
- [ ] Content revealed
- [ ] No data loss
- [ ] Seamless resume

---

### Test Case IT-STATE-003-06: BiometricChallenge Failure

**Objective**: Verify biometric failure handling.

**Test Steps**:
1. State: BiometricChallenge
2. Biometric failure
3. Verify handling

**Expected Results**:
- [ ] State remains BiometricChallenge
- [ ] Retry available
- [ ] Fallback to passcode
- [ ] After max failures → SignedOut

---

### Test Case IT-STATE-003-07: SignOut Action

**Objective**: Verify sign out transition.

**Test Steps**:
1. State: SignedIn
2. User signs out
3. Verify state

**Expected Results**:
- [ ] SignedIn → SignedOut
- [ ] Tokens cleared
- [ ] UI updates to signed out
- [ ] Local data optionally kept

---

## IT-STATE-004: Audio Session State Machine Tests

### Test Case IT-STATE-004-01: Inactive to Configured Transition

**Objective**: Verify audio session configuration.

**Test Steps**:
1. State: Inactive
2. Request audio session
3. Verify state

**Expected Results**:
- [ ] Inactive → Configured
- [ ] Category set to playAndRecord
- [ ] Mode set to voiceChat
- [ ] Options configured

```swift
func testInactiveToConfiguredTransition() async throws {
    let audioStateMachine = AudioSessionStateMachine()

    XCTAssertEqual(audioStateMachine.currentState, .inactive)

    try await audioStateMachine.configure()

    XCTAssertEqual(audioStateMachine.currentState, .configured)
}
```

---

### Test Case IT-STATE-004-02: Configured to Active Transition

**Objective**: Verify audio session activation.

**Test Steps**:
1. State: Configured
2. Activate session
3. Verify state

**Expected Results**:
- [ ] Configured → Active
- [ ] Audio routing established
- [ ] Input available
- [ ] Output available

---

### Test Case IT-STATE-004-03: Active to Interrupted Transition

**Objective**: Verify interruption handling.

**Test Steps**:
1. State: Active
2. Phone call comes in
3. Verify state

**Expected Results**:
- [ ] Active → Interrupted
- [ ] Recording paused
- [ ] UI shows interruption
- [ ] State preserved

---

### Test Case IT-STATE-004-04: Interrupted to Active Resume

**Objective**: Verify resume after interruption.

**Test Steps**:
1. State: Interrupted
2. Interruption ends
3. Verify state

**Expected Results**:
- [ ] Interrupted → Active
- [ ] Recording resumes
- [ ] UI updates
- [ ] No data loss

---

### Test Case IT-STATE-004-05: Route Change Handling

**Objective**: Verify audio route changes.

**Test Steps**:
1. State: Active
2. Bluetooth headset connected
3. Verify handling

**Expected Results**:
- [ ] Route change detected
- [ ] Session reconfigured
- [ ] Audio continues on new route
- [ ] UI shows new route if applicable

---

## IT-STATE-005: Navigation State Machine Tests

### Test Case IT-STATE-005-01: Splash to Onboarding Transition

**Objective**: Verify first launch navigation.

**Test Steps**:
1. State: Splash
2. First launch detected
3. Verify navigation

**Expected Results**:
- [ ] Splash → Onboarding
- [ ] Onboarding view displayed
- [ ] Cannot go back to splash
- [ ] Skip option available

```swift
func testSplashToOnboardingTransition() async throws {
    let navStateMachine = NavigationStateMachine()
    navStateMachine.isFirstLaunch = true

    await navStateMachine.completeSplash()

    XCTAssertEqual(navStateMachine.currentState, .onboarding)
}
```

---

### Test Case IT-STATE-005-02: Splash to Home Transition

**Objective**: Verify returning user navigation.

**Test Steps**:
1. State: Splash
2. Not first launch
3. Verify navigation

**Expected Results**:
- [ ] Splash → Home
- [ ] Home view displayed
- [ ] User state restored
- [ ] Start button available

---

### Test Case IT-STATE-005-03: Home to Interpretation Transition

**Objective**: Verify start interpretation navigation.

**Test Steps**:
1. State: Home
2. Tap Start
3. Verify navigation

**Expected Results**:
- [ ] Home → Interpretation
- [ ] Interpretation view displayed
- [ ] Back gesture available
- [ ] Language pair shown

---

### Test Case IT-STATE-005-04: Interpretation to Home Transition

**Objective**: Verify end interpretation navigation.

**Test Steps**:
1. State: Interpretation
2. Stop and save/discard
3. Verify navigation

**Expected Results**:
- [ ] Interpretation → Home
- [ ] Save prompt if unsaved
- [ ] Resources released
- [ ] Home view restored

---

### Test Case IT-STATE-005-05: Modal Presentation States

**Objective**: Verify modal presentation tracking.

**Test Steps**:
1. Present settings modal
2. Check modal state
3. Dismiss modal

**Expected Results**:
- [ ] Base state preserved
- [ ] Modal state tracked
- [ ] Dismiss returns to base
- [ ] No state corruption

---

## IT-STATE-006: State UI Synchronization Tests

### Test Case IT-STATE-006-01: State Change UI Update Timing

**Objective**: Verify UI updates on state change.

**Test Steps**:
1. Observe state change
2. Measure UI update timing
3. Verify synchronization

**Expected Results**:
- [ ] UI updates within 16ms (60fps)
- [ ] No visible lag
- [ ] Main thread execution
- [ ] Smooth transitions

```swift
func testStateChangeUIUpdateTiming() async throws {
    let viewModel = InterpretationViewModel(
        sourceLanguage: .japanese,
        targetLanguage: .english
    )

    let startTime = CFAbsoluteTimeGetCurrent()

    viewModel.toggleListening()

    await MainActor.run {
        // Force UI update
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let elapsed = (endTime - startTime) * 1000 // ms

    XCTAssertLessThan(elapsed, 16.0) // Within one frame
}
```

---

### Test Case IT-STATE-006-02: Concurrent State Updates

**Objective**: Verify thread safety of state updates.

**Test Steps**:
1. Trigger multiple state changes concurrently
2. Verify final state correct
3. No race conditions

**Expected Results**:
- [ ] State consistent
- [ ] No crashes
- [ ] UI updates sequenced
- [ ] Last write wins (if applicable)

---

### Test Case IT-STATE-006-03: State Persistence on Crash

**Objective**: Verify state survives crash.

**Test Steps**:
1. Set various states
2. Simulate crash
3. Restart and verify

**Expected Results**:
- [ ] Critical state persisted
- [ ] Recovery possible
- [ ] No corrupt state
- [ ] Graceful recovery UI

---

## IT-STATE-007: State-Driven UI Visibility Tests

### Test Case IT-STATE-007-01: Control Visibility by State

**Objective**: Verify controls show/hide by state.

**Test Steps**:
1. Check idle state controls
2. Check listening state controls
3. Verify visibility changes

**Expected Results**:
- [ ] Start button visible in Idle
- [ ] Stop button visible in Listening
- [ ] Correct controls for each state
- [ ] Smooth visibility transitions

---

### Test Case IT-STATE-007-02: Loading Indicator by State

**Objective**: Verify loading indicators.

**Test Steps**:
1. Trigger loading state
2. Check indicator visibility
3. Complete loading

**Expected Results**:
- [ ] Loading indicator in Configuring
- [ ] Loading indicator in Translating
- [ ] Hidden in stable states
- [ ] Accessible to VoiceOver

---

## Test Data Fixtures

### State Sequences

| Scenario | State Sequence |
|----------|---------------|
| Normal Start | Idle → Configuring → Listening |
| Full Cycle | Listening → Recognizing → Translating → Speaking → Listening |
| Error | Any → Error → Idle |
| Interrupt | Active → Interrupted → Active |

### State Timing

| Transition | Target Duration | Max Duration |
|------------|-----------------|--------------|
| Idle → Configuring | <500ms | 1s |
| Configuring → Listening | <200ms | 500ms |
| Recognizing → Translating | Immediate | 50ms |
| UI Update | <16ms | 33ms |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 68 test cases | AI Agent |
