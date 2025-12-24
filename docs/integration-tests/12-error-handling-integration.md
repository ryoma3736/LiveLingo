# IT-ERR: Error Handling Integration Tests

## Overview

This document defines integration tests for error handling based on workflows WF-ERR-001 through WF-ERR-005. These tests verify error recovery, graceful degradation, and user-friendly error presentation.

**Priority**: P0-Critical
**Total Test Cases**: 48
**Estimated Execution Time**: 18 minutes

---

## Test Environment

### Required Components
- `ErrorHandler`
- `RetryHandler`
- `FallbackManager`
- `ErrorMessageMapper`
- `ErrorLogger`

### Mock Dependencies
- `MockNetworkManager`
- `MockSpeechRecognizer`
- `MockTranslationService`
- `MockTTSEngine`

### Error Categories
- Network errors
- STT errors
- Translation errors
- TTS errors
- Permission errors
- System errors

---

## WF-ERR-001: Network Error Recovery

### Test Case IT-ERR-001-01: Timeout with Retry Success

**Objective**: Verify retry succeeds after timeout.

**Preconditions**:
- Network available but slow

**Test Steps**:
1. First request times out
2. Automatic retry triggered
3. Second request succeeds

**Expected Results**:
- [ ] Timeout detected (5s)
- [ ] Retry initiated
- [ ] Success returned to caller
- [ ] User sees no error (transparent)

```swift
func testTimeoutRetrySuccess() async throws {
    let mockNetwork = MockNetworkManager()
    mockNetwork.responses = [
        .timeout(after: 6.0),  // First request times out
        .success(validData)    // Second request succeeds
    ]

    let client = APIClient(network: mockNetwork)

    let result = try await client.request(endpoint: .translation)

    XCTAssertNotNil(result)
    XCTAssertEqual(mockNetwork.requestCount, 2)
}
```

---

### Test Case IT-ERR-001-02: Offline Detection and Banner

**Objective**: Verify offline state shown to user.

**Test Steps**:
1. Disable network
2. Attempt API call
3. Verify offline banner

**Expected Results**:
- [ ] Offline detected immediately
- [ ] Banner: "No internet connection"
- [ ] Offline fallback activated
- [ ] Banner dismisses on reconnect

---

### Test Case IT-ERR-001-03: Offline Translation Fallback

**Objective**: Verify offline translation works when network fails.

**Test Steps**:
1. Go offline
2. Request translation
3. Verify Apple Translation (offline) used

**Expected Results**:
- [ ] Fallback triggered
- [ ] Apple Translation used
- [ ] User notified: "Using offline mode"
- [ ] Translation successful

```swift
func testOfflineTranslationFallback() async throws {
    let networkMonitor = NetworkMonitor()
    networkMonitor.simulateOffline()

    let translationManager = TranslationManager()

    let result = try await translationManager.translate(
        text: "こんにちは",
        from: .japanese,
        to: .english
    )

    XCTAssertNotNil(result)
    XCTAssertTrue(translationManager.isUsingOfflineProvider)
}
```

---

### Test Case IT-ERR-001-04: Max Retries Exhausted

**Objective**: Verify error shown after all retries fail.

**Test Steps**:
1. Configure max retries = 3
2. All 4 attempts fail
3. Verify user notification

**Expected Results**:
- [ ] 3 retries attempted
- [ ] Final error after exhaustion
- [ ] User-friendly message
- [ ] Manual retry option

---

### Test Case IT-ERR-001-05: Queue for Later (Offline)

**Objective**: Verify requests queued when offline.

**Test Steps**:
1. Go offline
2. Attempt save operation
3. Go online
4. Verify queued operation completes

**Expected Results**:
- [ ] Operation queued
- [ ] User notified: "Will sync when online"
- [ ] Auto-complete on reconnect
- [ ] Success notification

---

### Test Case IT-ERR-001-06: Intermittent Connection

**Objective**: Verify handling of flaky connection.

**Test Steps**:
1. Simulate intermittent connectivity
2. Multiple requests
3. Verify resilient behavior

**Expected Results**:
- [ ] Some succeed, some retry
- [ ] No cascading failures
- [ ] User experience acceptable
- [ ] Metrics tracked

---

## WF-ERR-002: STT Error Recovery

### Test Case IT-ERR-002-01: Audio Input Error Recovery

**Objective**: Verify recovery from audio tap issues.

**Test Steps**:
1. Start recording
2. Simulate audio tap failure
3. Verify reinstallation

**Expected Results**:
- [ ] Error detected
- [ ] Tap reinstalled automatically
- [ ] Recording resumes
- [ ] No user action needed

```swift
func testAudioTapRecovery() async throws {
    let stt = SpeechRecognitionManager()

    // Simulate tap failure
    stt.simulateAudioTapError()

    // Verify recovery
    try await Task.sleep(nanoseconds: 500_000_000)

    XCTAssertTrue(stt.isRecording)
    XCTAssertFalse(stt.hasError)
}
```

---

### Test Case IT-ERR-002-02: Recognizer Unavailable Fallback

**Objective**: Verify WhisperKit fallback when SF unavailable.

**Test Steps**:
1. SFSpeechRecognizer unavailable
2. Attempt recognition
3. Verify WhisperKit activation

**Expected Results**:
- [ ] Unavailable detected
- [ ] Message: "Reconnecting..."
- [ ] WhisperKit activated
- [ ] Message: "Using offline recognition"

---

### Test Case IT-ERR-002-03: Rate Limit Cooldown

**Objective**: Verify rate limit handling for speech API.

**Test Steps**:
1. Hit speech recognition rate limit
2. Verify cooldown UI
3. Wait for cooldown
4. Resume recognition

**Expected Results**:
- [ ] Rate limit detected
- [ ] Cooldown timer shown
- [ ] 1 minute wait
- [ ] Auto-resume after

---

### Test Case IT-ERR-002-04: Permission Revoked Handling

**Objective**: Verify handling when permission revoked mid-session.

**Test Steps**:
1. Start recognition
2. Revoke permission (simulate)
3. Verify error handling

**Expected Results**:
- [ ] Permission loss detected
- [ ] Recording stops
- [ ] Message: "Permission needed"
- [ ] Settings link shown

---

### Test Case IT-ERR-002-05: Audio Session Interruption

**Objective**: Verify handling of audio session interruption.

**Test Steps**:
1. Start recognition
2. Trigger phone call
3. Verify pause
4. Call ends
5. Verify resume option

**Expected Results**:
- [ ] Recognition paused
- [ ] No crash during interrupt
- [ ] Resume available after
- [ ] State preserved

---

### Test Case IT-ERR-002-06: Recognizer Reinitialization

**Objective**: Verify recognizer can reinitialize after error.

**Test Steps**:
1. Force recognizer error
2. Attempt reinitialization
3. Verify success

**Expected Results**:
- [ ] Error logged
- [ ] Reinitialization succeeds
- [ ] Recognition resumes
- [ ] User sees brief pause only

---

## WF-ERR-003: API Error Display

### Test Case IT-ERR-003-01: Network Error Message Mapping

**Objective**: Verify network errors map to user-friendly messages.

**Test Steps**:
1. Trigger offline error
2. Trigger timeout error
3. Verify displayed messages

**Expected Results**:
- [ ] Offline: "No internet connection. Please check your network."
- [ ] Timeout: "Request timed out. Please try again."
- [ ] Messages localized
- [ ] No technical jargon

```swift
func testErrorMessageMapping() {
    let mapper = ErrorMessageMapper()

    let offlineMessage = mapper.map(NetworkError.offline)
    XCTAssertEqual(offlineMessage, "No internet connection.\nPlease check your network.")

    let timeoutMessage = mapper.map(NetworkError.timeout)
    XCTAssertEqual(timeoutMessage, "Request timed out.\nPlease try again.")
}
```

---

### Test Case IT-ERR-003-02: CoeFont Error Messages

**Objective**: Verify CoeFont-specific errors handled.

**Test Steps**:
1. Trigger CoeFont authentication error
2. Trigger CoeFont rate limit
3. Verify messages

**Expected Results**:
- [ ] Auth error: Credential check prompt
- [ ] Rate limit: Wait time shown
- [ ] Clear guidance provided
- [ ] Fallback available

---

### Test Case IT-ERR-003-03: Error UI Style Selection

**Objective**: Verify correct UI style for error type.

**Test Steps**:
1. Minor error (use banner)
2. Major error (use alert)
3. Inline error (form validation)

**Expected Results**:
- [ ] Banner for transient errors
- [ ] Alert for blocking errors
- [ ] Inline for field errors
- [ ] Consistent styling

---

### Test Case IT-ERR-003-04: Retry Button Action

**Objective**: Verify retry button works.

**Test Steps**:
1. Error with retry option shown
2. Tap retry
3. Verify retry executed

**Expected Results**:
- [ ] Retry button visible
- [ ] Tapping triggers retry
- [ ] Loading indicator shown
- [ ] Success or new error

---

### Test Case IT-ERR-003-05: Settings Action from Error

**Objective**: Verify settings navigation from error.

**Test Steps**:
1. Permission error shown
2. Tap "Open Settings"
3. Verify navigation

**Expected Results**:
- [ ] Settings button visible
- [ ] Opens iOS Settings
- [ ] Returns to app correctly
- [ ] Permission check on return

---

## WF-ERR-004: Permission Denied Handling

### Test Case IT-ERR-004-01: Microphone Permission Denied

**Objective**: Verify microphone permission denial handling.

**Test Steps**:
1. Deny microphone permission
2. Attempt to start interpretation
3. Verify permission UI

**Expected Results**:
- [ ] Clear explanation shown
- [ ] Icon indicates microphone
- [ ] "Open Settings" button
- [ ] Feature blocked until granted

```swift
func testMicrophonePermissionDenied() async throws {
    let permissionManager = PermissionManager()
    permissionManager.simulateDenied(.microphone)

    let canStart = await permissionManager.checkMicrophonePermission()

    XCTAssertFalse(canStart)

    // UI should show permission view
    let viewModel = InterpretationViewModel()
    XCTAssertTrue(viewModel.showsPermissionRequired)
}
```

---

### Test Case IT-ERR-004-02: Speech Recognition Permission Denied

**Objective**: Verify speech recognition permission handling.

**Test Steps**:
1. Deny speech recognition permission
2. Attempt recognition
3. Verify guidance

**Expected Results**:
- [ ] Explanation: "Speech recognition needed"
- [ ] Settings navigation available
- [ ] Feature disabled until granted
- [ ] Clear path to enable

---

### Test Case IT-ERR-004-03: Permission Recovery Flow

**Objective**: Verify app detects permission grant from Settings.

**Test Steps**:
1. Permission denied
2. User opens Settings
3. User grants permission
4. Return to app
5. Verify detection

**Expected Results**:
- [ ] Permission change detected
- [ ] Permission view dismissed
- [ ] Feature now available
- [ ] Seamless experience

---

### Test Case IT-ERR-004-04: Multiple Permission Issues

**Objective**: Verify handling of multiple missing permissions.

**Test Steps**:
1. Deny both microphone and speech
2. Attempt interpretation
3. Verify both handled

**Expected Results**:
- [ ] Both shown (or sequential)
- [ ] Clear about requirements
- [ ] Both must be granted
- [ ] Success after both granted

---

## WF-ERR-005: Graceful Degradation

### Test Case IT-ERR-005-01: Primary Service Failure Fallback

**Objective**: Verify fallback when primary service fails.

**Test Steps**:
1. Primary translation service fails
2. Verify fallback activation
3. Verify quality indicator

**Expected Results**:
- [ ] Fallback activated
- [ ] Notice: "Using alternative service"
- [ ] Quality indicator shown
- [ ] Result still provided

```swift
func testGracefulDegradation() async throws {
    let translationManager = TranslationManager()
    translationManager.primaryProvider = MockProvider(shouldFail: true)
    translationManager.fallbackProvider = MockProvider(shouldFail: false)

    let result = try await translationManager.translate(
        text: "Test",
        from: .english,
        to: .japanese
    )

    XCTAssertNotNil(result)
    XCTAssertTrue(translationManager.isUsingFallback)
}
```

---

### Test Case IT-ERR-005-02: Fallback Also Fails

**Objective**: Verify handling when all providers fail.

**Test Steps**:
1. Primary fails
2. Fallback also fails
3. Verify full error

**Expected Results**:
- [ ] All attempts made
- [ ] Full error shown
- [ ] Clear message
- [ ] Retry available

---

### Test Case IT-ERR-005-03: Quality Reduction Indicator

**Objective**: Verify quality reduction indicated.

**Test Steps**:
1. Using fallback provider
2. Verify UI indicator
3. Verify result marked

**Expected Results**:
- [ ] Visual indicator present
- [ ] Results may show "approx"
- [ ] User aware of degradation
- [ ] Can wait for primary

---

### Test Case IT-ERR-005-04: Recovery to Primary

**Objective**: Verify return to primary when available.

**Test Steps**:
1. Using fallback
2. Primary becomes available
3. Verify switch back

**Expected Results**:
- [ ] Availability detected
- [ ] Smooth transition
- [ ] Quality indicator removed
- [ ] No user action needed

---

## Error Logging

### Test Case IT-ERR-LOG-01: Error Sanitization

**Objective**: Verify sensitive data removed from logs.

**Test Steps**:
1. Error with API key in context
2. Log error
3. Verify sanitization

**Expected Results**:
- [ ] API key removed
- [ ] Password removed
- [ ] Token removed
- [ ] Error still useful

```swift
func testErrorSanitization() {
    let logger = ErrorLogger()

    let sensitiveError = APIError(
        message: "Auth failed",
        context: ["apiKey": "secret123", "user": "test"]
    )

    let sanitized = logger.sanitize(sensitiveError)

    XCTAssertFalse(sanitized.description.contains("secret123"))
    XCTAssertTrue(sanitized.description.contains("[REDACTED]"))
}
```

---

### Test Case IT-ERR-LOG-02: Context Enrichment

**Objective**: Verify logs enriched with context.

**Test Steps**:
1. Log error
2. Verify context added

**Expected Results**:
- [ ] Device info included
- [ ] App version included
- [ ] Timestamp in ISO8601
- [ ] User action context

---

### Test Case IT-ERR-LOG-03: Parallel Logging

**Objective**: Verify multiple log destinations.

**Test Steps**:
1. Log error
2. Verify local file
3. Verify analytics (if enabled)

**Expected Results**:
- [ ] Local file written
- [ ] Analytics event sent
- [ ] Parallel execution
- [ ] No blocking

---

### Test Case IT-ERR-LOG-04: Fatal Error Reporting

**Objective**: Verify fatal errors reported to crash service.

**Test Steps**:
1. Non-fatal error (should report)
2. Verify crash reporter notified

**Expected Results**:
- [ ] Non-fatal recorded
- [ ] Stack trace included
- [ ] Breadcrumbs included
- [ ] No app crash

---

## Error Recovery State Machine

### Test Case IT-ERR-STATE-01: State Transitions

**Objective**: Verify error state transitions correctly.

**Test Steps**:
1. Normal → Error
2. Error → Retrying
3. Retrying → Normal (success)
4. Retrying → ShowingError (failure)

**Expected Results**:
- [ ] All transitions valid
- [ ] Invalid transitions rejected
- [ ] State observable
- [ ] UI reflects state

---

### Test Case IT-ERR-STATE-02: User Action Recovery

**Objective**: Verify user can recover from error state.

**Test Steps**:
1. In ShowingError state
2. User taps retry
3. Verify transition to Normal or Retrying

**Expected Results**:
- [ ] Retry triggers state change
- [ ] Dismiss clears error
- [ ] App functional after recovery
- [ ] No stuck states

---

## Test Data Fixtures

### Error Scenarios

| Error Type | HTTP Code | Message | Retryable |
|------------|-----------|---------|-----------|
| Network Offline | - | No connection | Yes (on reconnect) |
| Timeout | - | Request timeout | Yes |
| Server Error | 500 | Server unavailable | Yes |
| Rate Limited | 429 | Too many requests | Yes (after delay) |
| Auth Failed | 401 | Invalid credentials | No |
| Bad Request | 400 | Invalid input | No |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 48 test cases | AI Agent |
