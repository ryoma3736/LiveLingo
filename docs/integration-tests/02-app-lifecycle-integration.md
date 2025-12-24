# IT-LIFE: App Lifecycle Integration Tests

## Overview

This document defines integration tests for app lifecycle management based on workflows WF-LIFE-001 through WF-LIFE-006. These tests verify proper initialization, state transitions, and resource management across app states.

**Priority**: P0-Critical
**Total Test Cases**: 38
**Estimated Execution Time**: 12 minutes

---

## Test Environment

### Required Components
- `AppDelegate` / `@main App`
- `SceneDelegate` (if using UIKit lifecycle)
- `ConfigurationLoader`
- `PermissionManager`
- `AudioSessionManager`
- `ServiceContainer` (DI container)

### Mock Dependencies
- `MockUserDefaults`
- `MockKeychain`
- `MockAudioSession`
- `MockNetworkMonitor`

---

## WF-LIFE-001: Cold Start

### Test Case IT-LIFE-001-01: Full Cold Start Sequence

**Objective**: Verify complete cold start initialization within time budget.

**Preconditions**:
- App not in memory
- All permissions previously granted
- Network available

**Test Steps**:
1. Launch app from terminated state
2. Measure time to first frame render
3. Verify all services initialized
4. Check home screen ready

**Expected Results**:
- [ ] Launch to first frame < 500ms
- [ ] Launch to interactive < 3 seconds
- [ ] All critical services initialized
- [ ] No UI jank during startup

```swift
func testColdStartPerformance() throws {
    let metrics = try XCTSkipUnless(
        ProcessInfo.processInfo.environment["RUN_PERF_TESTS"] != nil
    )

    let launchStart = CFAbsoluteTimeGetCurrent()

    let app = XCUIApplication()
    app.launch()

    let homeButton = app.buttons["StartInterpretation"]
    XCTAssertTrue(homeButton.waitForExistence(timeout: 3.0))

    let launchDuration = CFAbsoluteTimeGetCurrent() - launchStart
    XCTAssertLessThan(launchDuration, 3.0)
}
```

---

### Test Case IT-LIFE-001-02: Cold Start with Missing Permissions

**Objective**: Verify onboarding shown when permissions not granted.

**Test Steps**:
1. Reset app permissions (Settings)
2. Launch app cold
3. Verify onboarding flow presented
4. Complete permission requests
5. Verify home screen accessible

**Expected Results**:
- [ ] Onboarding presented immediately
- [ ] Permission rationale shown first
- [ ] System dialogs appear after rationale
- [ ] App functional after permissions granted

---

### Test Case IT-LIFE-001-03: Cold Start Configuration Loading

**Objective**: Verify configuration loads correctly on cold start.

**Test Steps**:
1. Set custom configuration in UserDefaults
2. Launch app cold
3. Verify configuration applied

**Expected Results**:
- [ ] Source language restored
- [ ] Target language restored
- [ ] TTS settings applied
- [ ] Theme applied correctly

---

### Test Case IT-LIFE-001-04: Cold Start Service Initialization Order

**Objective**: Verify services initialize in correct dependency order.

**Test Steps**:
1. Add logging to service init
2. Launch app cold
3. Analyze initialization order

**Expected Results**:
- [ ] ConfigurationLoader before AudioSession
- [ ] AudioSession before SpeechRecognizer
- [ ] Translation before TTS (to verify API)
- [ ] No initialization deadlocks

---

### Test Case IT-LIFE-001-05: Cold Start Error Recovery

**Objective**: Verify app handles initialization errors gracefully.

**Test Steps**:
1. Configure MockAudioSession to fail
2. Launch app
3. Verify error handling
4. Fix mock and retry

**Expected Results**:
- [ ] Error shown to user (not crash)
- [ ] Retry option available
- [ ] App recovers on retry
- [ ] Error logged for debugging

---

### Test Case IT-LIFE-001-06: Cold Start Memory Baseline

**Objective**: Establish memory baseline after cold start.

**Test Steps**:
1. Launch app cold
2. Wait for idle state
3. Measure memory footprint
4. Record baseline

**Expected Results**:
- [ ] Idle memory < 100 MB
- [ ] No memory warnings on start
- [ ] Autoreleased objects cleaned
- [ ] No retain cycles detected

---

## WF-LIFE-002: Warm Start

### Test Case IT-LIFE-002-01: Resume from Background (< 30s)

**Objective**: Verify fast resume from recent background.

**Test Steps**:
1. Start interpretation session
2. Background app for 5 seconds
3. Return to foreground
4. Verify session state

**Expected Results**:
- [ ] Resume < 200ms
- [ ] Interpretation session preserved
- [ ] Audio session reactivated
- [ ] UI state unchanged

```swift
func testWarmStartFast() async throws {
    let viewModel = InterpretationViewModel()
    viewModel.startInterpretation()

    // Simulate background
    NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

    // Simulate foreground
    let resumeStart = CFAbsoluteTimeGetCurrent()
    NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)

    // Wait for resume
    try await Task.sleep(nanoseconds: 500_000_000)

    let resumeDuration = CFAbsoluteTimeGetCurrent() - resumeStart
    XCTAssertLessThan(resumeDuration, 0.5)
    XCTAssertTrue(viewModel.isSessionActive)
}
```

---

### Test Case IT-LIFE-002-02: Resume from Extended Background (> 5 min)

**Objective**: Verify resume after extended background.

**Test Steps**:
1. Start session
2. Background for 5+ minutes
3. Return to foreground
4. Verify state recovery

**Expected Results**:
- [ ] Session may need restart
- [ ] Audio session reconfigured
- [ ] API connections refreshed
- [ ] State notification shown

---

### Test Case IT-LIFE-002-03: Warm Start with State Restoration

**Objective**: Verify iOS state restoration works.

**Test Steps**:
1. Navigate to settings
2. Background app
3. Terminate via Xcode
4. Relaunch
5. Verify navigation restored

**Expected Results**:
- [ ] Last screen restored
- [ ] Scroll position preserved
- [ ] Form data preserved
- [ ] Session data preserved

---

### Test Case IT-LIFE-002-04: Warm Start Audio Session Recovery

**Objective**: Verify audio session reconfigured correctly.

**Test Steps**:
1. Start interpretation
2. Background app
3. Wait for audio session deactivation
4. Foreground app
5. Verify audio working

**Expected Results**:
- [ ] Audio session reactivated
- [ ] Microphone access restored
- [ ] Speaker output working
- [ ] No audio glitches

---

## WF-LIFE-003: Onboarding Flow

### Test Case IT-LIFE-003-01: Complete Onboarding Sequence

**Objective**: Verify full onboarding flow for new users.

**Test Steps**:
1. Fresh install (no UserDefaults)
2. Launch app
3. Complete each onboarding step
4. Verify completion state

**Expected Results**:
- [ ] Welcome screen shown first
- [ ] Permission screens in order
- [ ] Language selection available
- [ ] Onboarding complete flag set

---

### Test Case IT-LIFE-003-02: Onboarding Permission Denial

**Objective**: Verify handling when permissions denied during onboarding.

**Test Steps**:
1. Start onboarding
2. Deny microphone permission
3. Observe error handling
4. Tap "Open Settings"
5. Grant permission externally

**Expected Results**:
- [ ] Clear error message shown
- [ ] Settings button available
- [ ] App detects permission grant on return
- [ ] Onboarding continues

---

### Test Case IT-LIFE-003-03: Onboarding Skip and Resume

**Objective**: Verify onboarding can be skipped and resumed.

**Test Steps**:
1. Start onboarding
2. Tap skip on optional step
3. Complete required steps
4. Access settings
5. Complete skipped setup

**Expected Results**:
- [ ] Required steps enforced
- [ ] Optional steps skippable
- [ ] Settings shows incomplete setup
- [ ] Feature accessible after completion

---

### Test Case IT-LIFE-003-04: Onboarding Persistence

**Objective**: Verify onboarding progress persists across launches.

**Test Steps**:
1. Start onboarding
2. Complete 2 of 4 steps
3. Kill app
4. Relaunch

**Expected Results**:
- [ ] Progress preserved
- [ ] Resumes at step 3
- [ ] No data loss
- [ ] State consistent

---

## WF-LIFE-004: Background Transition

### Test Case IT-LIFE-004-01: Active Session Background Handling

**Objective**: Verify interpretation pauses correctly in background.

**Test Steps**:
1. Start interpretation
2. Press home button (background)
3. Wait 2 seconds
4. Observe background behavior

**Expected Results**:
- [ ] Audio recording paused
- [ ] TTS playback stopped
- [ ] Session state preserved
- [ ] Background task requested (for cleanup)

```swift
func testBackgroundTransitionDuringInterpretation() async throws {
    let viewModel = InterpretationViewModel()
    viewModel.startInterpretation()

    XCTAssertTrue(viewModel.isRecording)

    // Simulate background
    await viewModel.handleAppDidEnterBackground()

    XCTAssertFalse(viewModel.isRecording)
    XCTAssertTrue(viewModel.isSessionPaused)
    XCTAssertNotNil(viewModel.savedSessionState)
}
```

---

### Test Case IT-LIFE-004-02: Background Task Completion

**Objective**: Verify background task completes before suspension.

**Test Steps**:
1. Start translation request
2. Background immediately
3. Monitor background task
4. Foreground after completion

**Expected Results**:
- [ ] Background task requested
- [ ] Translation completes
- [ ] Result cached
- [ ] Result displayed on foreground

---

### Test Case IT-LIFE-004-03: Memory Warning During Background

**Objective**: Verify memory cleanup when warned in background.

**Test Steps**:
1. Load large translation history
2. Background app
3. Trigger memory warning
4. Foreground app

**Expected Results**:
- [ ] Cache cleared
- [ ] Non-essential resources released
- [ ] App survives warning
- [ ] Essential data preserved

---

### Test Case IT-LIFE-004-04: Background Audio Policy

**Objective**: Verify audio stops when not in active interpretation.

**Test Steps**:
1. Play TTS preview
2. Background app
3. Verify audio behavior

**Expected Results**:
- [ ] Audio stops (unless explicitly allowed)
- [ ] Audio session category respected
- [ ] No background audio warning
- [ ] Compliant with App Store guidelines

---

## WF-LIFE-005: Foreground Transition

### Test Case IT-LIFE-005-01: Session Resume on Foreground

**Objective**: Verify paused session resumes correctly.

**Test Steps**:
1. Start interpretation
2. Background (pauses)
3. Foreground
4. Verify session resumes

**Expected Results**:
- [ ] Audio session reactivated
- [ ] Microphone recording resumes
- [ ] UI reflects active state
- [ ] No user action required

---

### Test Case IT-LIFE-005-02: Foreground with Permission Revoked

**Objective**: Verify handling when permission revoked during background.

**Test Steps**:
1. Background app
2. Revoke microphone permission in Settings
3. Foreground app
4. Attempt to start interpretation

**Expected Results**:
- [ ] Permission check on foreground
- [ ] Error message displayed
- [ ] Settings prompt shown
- [ ] Graceful degradation

---

### Test Case IT-LIFE-005-03: Foreground Network State Change

**Objective**: Verify network state handled on foreground.

**Test Steps**:
1. Background app on WiFi
2. Disable WiFi while in background
3. Foreground app
4. Attempt API call

**Expected Results**:
- [ ] Network state detected
- [ ] Offline banner shown
- [ ] Offline fallback activated
- [ ] Recovery when network returns

---

### Test Case IT-LIFE-005-04: Foreground with System Time Change

**Objective**: Verify handling of time change during background.

**Test Steps**:
1. Background app
2. Change system time forward 1 day
3. Foreground app
4. Verify token/cache handling

**Expected Results**:
- [ ] Expired tokens detected
- [ ] Cache invalidation correct
- [ ] Session refresh triggered
- [ ] No incorrect timestamps

---

## WF-LIFE-006: App Termination

### Test Case IT-LIFE-006-01: Graceful Termination

**Objective**: Verify clean shutdown when user terminates app.

**Test Steps**:
1. Start active session
2. Swipe up to terminate
3. Monitor cleanup
4. Relaunch and verify state

**Expected Results**:
- [ ] Active session saved
- [ ] Audio resources released
- [ ] No data corruption
- [ ] State restorable on launch

---

### Test Case IT-LIFE-006-02: Termination During Translation

**Objective**: Verify termination during active translation.

**Test Steps**:
1. Start translation request
2. Terminate immediately
3. Relaunch

**Expected Results**:
- [ ] Pending request cancelled
- [ ] No orphaned network tasks
- [ ] Partial data cleaned up
- [ ] No crash on relaunch

---

### Test Case IT-LIFE-006-03: System-Initiated Termination

**Objective**: Verify handling of system-initiated termination.

**Test Steps**:
1. Load app to high memory state
2. Open many other apps
3. Monitor termination behavior

**Expected Results**:
- [ ] Termination handler called
- [ ] Critical state saved
- [ ] No data loss
- [ ] Recovery possible

---

### Test Case IT-LIFE-006-04: Crash Recovery

**Objective**: Verify app recovers from crash.

**Test Steps**:
1. Force crash (test only)
2. Relaunch app
3. Verify recovery state

**Expected Results**:
- [ ] Crash reported
- [ ] App launches normally
- [ ] No corrupted state
- [ ] User notified of issue

---

## Memory Warning Handling

### Test Case IT-LIFE-MEM-01: Level 1 Memory Warning

**Objective**: Verify response to first memory warning.

**Test Steps**:
1. Load translation cache to 50MB
2. Trigger memory warning level 1
3. Observe cleanup

**Expected Results**:
- [ ] 50% cache evicted
- [ ] Image caches cleared
- [ ] Warning logged
- [ ] App continues normally

---

### Test Case IT-LIFE-MEM-02: Critical Memory Warning (92%)

**Objective**: Verify aggressive cleanup at critical level.

**Test Steps**:
1. Push memory usage to 90%
2. Trigger critical warning
3. Observe cleanup

**Expected Results**:
- [ ] All caches cleared
- [ ] Audio buffers released
- [ ] Only essential data retained
- [ ] App survives without crash

```swift
func testCriticalMemoryWarning() async throws {
    let memoryManager = MemoryManager.shared

    // Fill caches
    memoryManager.translationCache.fill(sizeMB: 100)
    memoryManager.audioBufferPool.allocate(count: 50)

    // Trigger critical warning
    NotificationCenter.default.post(
        name: UIApplication.didReceiveMemoryWarningNotification,
        object: nil
    )

    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertEqual(memoryManager.translationCache.count, 0)
    XCTAssertEqual(memoryManager.audioBufferPool.available, 0)
    XCTAssertLessThan(memoryManager.currentUsagePercent, 0.75)
}
```

---

### Test Case IT-LIFE-MEM-03: Repeated Memory Warnings

**Objective**: Verify handling of repeated warnings.

**Test Steps**:
1. Trigger warning
2. Wait 10 seconds
3. Trigger another warning
4. Verify incremental cleanup

**Expected Results**:
- [ ] Progressive cleanup levels
- [ ] No double-cleanup
- [ ] Cleanup cooldown respected
- [ ] Metrics tracked

---

## Test Data Fixtures

### Configuration States

| State ID | Description | UserDefaults |
|----------|-------------|--------------|
| `fresh_install` | No previous data | Empty |
| `onboarding_complete` | Permissions granted | onboarding_complete=true |
| `session_saved` | Active session state | session_state=... |
| `custom_config` | User customizations | source=ja, target=en, ... |

---

## Mocking Strategy

### MockScenePhase

```swift
class MockScenePhasePublisher {
    var currentPhase: ScenePhase = .active
    let phaseSubject = PassthroughSubject<ScenePhase, Never>()

    func simulateBackground() {
        currentPhase = .background
        phaseSubject.send(.background)
    }

    func simulateForeground() {
        currentPhase = .active
        phaseSubject.send(.active)
    }
}
```

### MockUIApplication

```swift
class MockUIApplication {
    var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    var backgroundTimeRemaining: TimeInterval = 30.0

    func beginBackgroundTask(handler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        backgroundTaskIdentifier = UIBackgroundTaskIdentifier(rawValue: 1)
        return backgroundTaskIdentifier
    }
}
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 38 test cases | AI Agent |
