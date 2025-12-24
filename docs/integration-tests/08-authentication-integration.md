# IT-AUTH: Authentication Integration Tests

## Overview

This document defines integration tests for authentication based on workflows WF-AUTH-001 through WF-AUTH-004. These tests verify Sign in with Apple, biometric authentication, session management, and sign out flows.

**Priority**: P1-High
**Total Test Cases**: 28
**Estimated Execution Time**: 10 minutes

---

## Test Environment

### Required Components
- `AuthenticationManager`
- `ASAuthorizationController` (Sign in with Apple)
- `LAContext` (Biometric)
- `KeychainManager`
- `SessionManager`

### Mock Dependencies
- `MockASAuthorizationController`
- `MockLAContext`
- `MockKeychain`

### Requirements
- Device with Face ID or Touch ID
- Apple ID account (for real tests)
- Biometric enrollment

---

## WF-AUTH-001: Sign in with Apple

### Test Case IT-AUTH-001-01: Successful Sign In

**Objective**: Verify complete Sign in with Apple flow.

**Preconditions**:
- User has Apple ID
- Not previously signed in

**Test Steps**:
1. Tap "Sign in with Apple" button
2. System presents authorization
3. User authenticates with Face ID/Touch ID
4. Receive credential response
5. Store user ID in Keychain

**Expected Results**:
- [ ] Authorization controller presented
- [ ] User identity received
- [ ] User ID stored securely
- [ ] UI updated to signed-in state

```swift
func testSignInWithAppleSuccess() async throws {
    let authManager = AuthenticationManager()

    let mockController = MockASAuthorizationController()
    mockController.mockCredential = ASAuthorizationAppleIDCredential(
        user: "test-user-id",
        email: "test@example.com",
        fullName: PersonNameComponents(givenName: "Test", familyName: "User")
    )

    authManager.authorizationController = mockController

    try await authManager.signInWithApple()

    XCTAssertTrue(authManager.isSignedIn)
    XCTAssertEqual(authManager.currentUser?.id, "test-user-id")
}
```

---

### Test Case IT-AUTH-001-02: First-Time Sign In (Full Name/Email)

**Objective**: Verify full name and email captured on first sign in.

**Test Steps**:
1. Sign in for first time
2. User authorizes name and email
3. Verify data received

**Expected Results**:
- [ ] Full name provided
- [ ] Email provided (or hidden email)
- [ ] Data stored appropriately
- [ ] Privacy respected

---

### Test Case IT-AUTH-001-03: Subsequent Sign In (No Email)

**Objective**: Verify handling when Apple doesn't provide email again.

**Test Steps**:
1. Sign in after initial
2. Apple provides only user ID
3. Verify existing data used

**Expected Results**:
- [ ] User ID matches
- [ ] Existing profile loaded
- [ ] No error on missing email
- [ ] Session established

---

### Test Case IT-AUTH-001-04: Sign In Cancelled by User

**Objective**: Verify graceful handling of cancellation.

**Test Steps**:
1. Initiate sign in
2. User taps Cancel
3. Verify state unchanged

**Expected Results**:
- [ ] Cancellation detected
- [ ] No error shown (user action)
- [ ] App remains on sign-in screen
- [ ] Can retry

---

### Test Case IT-AUTH-001-05: Sign In Authorization Error

**Objective**: Verify handling of authorization failure.

**Test Steps**:
1. Simulate authorization error
2. Verify error handling

**Expected Results**:
- [ ] Error detected
- [ ] User-friendly message
- [ ] Retry available
- [ ] Fallback offered (if any)

---

### Test Case IT-AUTH-001-06: User ID Storage in Keychain

**Objective**: Verify user ID stored securely.

**Test Steps**:
1. Complete sign in
2. Verify Keychain entry
3. Verify accessibility settings

**Expected Results**:
- [ ] User ID in Keychain
- [ ] Access = whenUnlockedThisDeviceOnly
- [ ] Encrypted at rest
- [ ] Retrievable after restart

---

### Test Case IT-AUTH-001-07: Credential State Verification

**Objective**: Verify credential state checked on app launch.

**Test Steps**:
1. Sign in
2. Restart app
3. Verify credential state check

**Expected Results**:
- [ ] Credential state checked
- [ ] authorized = continue session
- [ ] revoked = require re-auth
- [ ] notFound = new user

```swift
func testCredentialStateVerification() async throws {
    let authManager = AuthenticationManager()
    authManager.storedUserId = "test-user-id"

    // Simulate app launch
    let state = try await authManager.checkCredentialState()

    switch state {
    case .authorized:
        XCTAssertTrue(authManager.isSignedIn)
    case .revoked, .notFound:
        XCTAssertFalse(authManager.isSignedIn)
    default:
        break
    }
}
```

---

## WF-AUTH-002: Biometric Authentication

### Test Case IT-AUTH-002-01: Face ID Authentication

**Objective**: Verify Face ID authentication flow.

**Preconditions**:
- Face ID enrolled
- Device supports Face ID

**Test Steps**:
1. Request biometric authentication
2. Present Face ID prompt
3. User authenticates
4. Verify success

**Expected Results**:
- [ ] Face ID prompt shown
- [ ] Reason string displayed
- [ ] Success callback on match
- [ ] Access granted

```swift
func testFaceIDAuthentication() async throws {
    let authManager = AuthenticationManager()
    let context = LAContext()

    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        throw XCTSkip("Biometrics not available")
    }

    let success = try await authManager.authenticateWithBiometrics(
        reason: "Unlock LiveLingo"
    )

    XCTAssertTrue(success)
}
```

---

### Test Case IT-AUTH-002-02: Touch ID Authentication

**Objective**: Verify Touch ID authentication flow.

**Preconditions**:
- Touch ID enrolled
- Device supports Touch ID

**Test Steps**:
1. Request biometric authentication
2. Present Touch ID prompt
3. User authenticates
4. Verify success

**Expected Results**:
- [ ] Touch ID prompt shown
- [ ] Fingerprint recognized
- [ ] Success callback
- [ ] Access granted

---

### Test Case IT-AUTH-002-03: Biometric Failure Fallback

**Objective**: Verify fallback to passcode on biometric failure.

**Test Steps**:
1. Fail biometric 3 times
2. Verify passcode option offered
3. Enter passcode
4. Verify success

**Expected Results**:
- [ ] Biometric failure counted
- [ ] Passcode fallback available
- [ ] Passcode authentication works
- [ ] Access granted

---

### Test Case IT-AUTH-002-04: Biometric Not Enrolled

**Objective**: Verify handling when biometrics not set up.

**Test Steps**:
1. Device without biometric enrollment
2. Request biometric auth
3. Verify error handling

**Expected Results**:
- [ ] notEnrolled error detected
- [ ] User prompted to set up
- [ ] Fallback to passcode
- [ ] Settings link available

---

### Test Case IT-AUTH-002-05: Biometric Lockout

**Objective**: Verify handling of biometric lockout.

**Test Steps**:
1. Fail biometric many times
2. Verify lockout detected
3. Handle lockout gracefully

**Expected Results**:
- [ ] Lockout detected
- [ ] Passcode required
- [ ] Clear message to user
- [ ] Recovery possible

---

### Test Case IT-AUTH-002-06: Biometric Changed (Re-enrollment)

**Objective**: Verify detection of biometric changes.

**Test Steps**:
1. Initial biometric auth
2. User adds new fingerprint/face
3. Detect change on next auth

**Expected Results**:
- [ ] Change detected
- [ ] May require re-authentication
- [ ] Security policy enforced
- [ ] User notified

---

## WF-AUTH-003: Session Validation

### Test Case IT-AUTH-003-01: Valid Session Check

**Objective**: Verify valid session recognized.

**Test Steps**:
1. User signed in
2. Check session validity
3. Verify session active

**Expected Results**:
- [ ] Session token exists
- [ ] Token not expired
- [ ] User ID valid
- [ ] isSessionValid = true

```swift
func testValidSessionCheck() async throws {
    let sessionManager = SessionManager()

    // Create session
    sessionManager.createSession(
        userId: "test-user",
        expiresAt: Date().addingTimeInterval(3600)
    )

    let isValid = await sessionManager.validateSession()

    XCTAssertTrue(isValid)
}
```

---

### Test Case IT-AUTH-003-02: Expired Session Detection

**Objective**: Verify expired session detected.

**Test Steps**:
1. Create session with short expiry
2. Wait for expiration
3. Check session validity

**Expected Results**:
- [ ] Expiration detected
- [ ] isSessionValid = false
- [ ] Re-authentication triggered
- [ ] User notified

---

### Test Case IT-AUTH-003-03: Session Refresh

**Objective**: Verify session can be refreshed.

**Test Steps**:
1. Session near expiry
2. Trigger refresh
3. Verify new expiry

**Expected Results**:
- [ ] Refresh token used
- [ ] New session created
- [ ] Expiry extended
- [ ] Seamless to user

---

### Test Case IT-AUTH-003-04: Concurrent Session Handling

**Objective**: Verify single session policy.

**Test Steps**:
1. Sign in on device A
2. Sign in on device B
3. Verify device A session

**Expected Results**:
- [ ] New sign in creates new session
- [ ] Old session may be invalidated (policy)
- [ ] User notified if applicable
- [ ] Data synced correctly

---

### Test Case IT-AUTH-003-05: Session Persistence Across App Restart

**Objective**: Verify session survives app restart.

**Test Steps**:
1. Sign in
2. Kill app
3. Relaunch
4. Verify session

**Expected Results**:
- [ ] Session data in Keychain
- [ ] Session restored on launch
- [ ] No re-authentication needed
- [ ] User experience seamless

---

## WF-AUTH-004: Sign Out

### Test Case IT-AUTH-004-01: Complete Sign Out

**Objective**: Verify full sign out flow.

**Test Steps**:
1. User taps Sign Out
2. Confirm dialog shown
3. User confirms
4. Clear session and credentials

**Expected Results**:
- [ ] Confirmation shown
- [ ] Session cleared
- [ ] Keychain data removed
- [ ] Navigate to sign-in

```swift
func testCompleteSignOut() async throws {
    let authManager = AuthenticationManager()
    authManager.simulateSignedInState()

    XCTAssertTrue(authManager.isSignedIn)

    try await authManager.signOut()

    XCTAssertFalse(authManager.isSignedIn)
    XCTAssertNil(authManager.currentUser)
    XCTAssertNil(KeychainManager.shared.getString(forKey: "user_id"))
}
```

---

### Test Case IT-AUTH-004-02: Sign Out Credential Cleanup

**Objective**: Verify all credentials removed.

**Test Steps**:
1. Sign out
2. Check Keychain for user data
3. Check caches

**Expected Results**:
- [ ] User ID removed
- [ ] Session token removed
- [ ] Refresh token removed
- [ ] Sensitive data cleared

---

### Test Case IT-AUTH-004-03: Sign Out with Pending Sync

**Objective**: Verify handling when data pending sync.

**Test Steps**:
1. Have unsaved data
2. Attempt sign out
3. Verify prompt

**Expected Results**:
- [ ] Warning about unsaved data
- [ ] Option to sync first
- [ ] Option to proceed anyway
- [ ] Data handled per choice

---

### Test Case IT-AUTH-004-04: Sign Out UI Navigation

**Objective**: Verify navigation after sign out.

**Test Steps**:
1. Deep in app hierarchy
2. Sign out
3. Verify navigation

**Expected Results**:
- [ ] Navigate to sign-in screen
- [ ] Clear navigation stack
- [ ] No back navigation to auth content
- [ ] Clean slate

---

### Test Case IT-AUTH-004-05: Sign Out Cache Clearing

**Objective**: Verify caches cleared on sign out.

**Test Steps**:
1. Build up caches during session
2. Sign out
3. Verify cache state

**Expected Results**:
- [ ] Translation cache cleared
- [ ] Conversation history cleared (if not persisted)
- [ ] User preferences may persist
- [ ] Privacy maintained

---

### Test Case IT-AUTH-004-06: Sign Out Error Handling

**Objective**: Verify handling of sign out failure.

**Test Steps**:
1. Simulate Keychain error
2. Attempt sign out
3. Verify handling

**Expected Results**:
- [ ] Error caught
- [ ] Retry available
- [ ] Partial cleanup done
- [ ] User can retry

---

## Security Tests

### Test Case IT-AUTH-SEC-01: Credential Storage Security

**Objective**: Verify credentials stored securely.

**Test Steps**:
1. Store credentials
2. Attempt unauthorized access
3. Verify protection

**Expected Results**:
- [ ] Keychain protection active
- [ ] Access requires auth
- [ ] Encrypted at rest
- [ ] No plaintext leaks

---

### Test Case IT-AUTH-SEC-02: Session Token Protection

**Objective**: Verify session tokens protected.

**Test Steps**:
1. Create session
2. Inspect token storage
3. Verify security

**Expected Results**:
- [ ] Token not in UserDefaults
- [ ] Token in Keychain
- [ ] Not logged to console
- [ ] Not in crash reports

---

## Test Data Fixtures

### Mock Credentials

| User ID | Email | Name | State |
|---------|-------|------|-------|
| `user-001` | test@example.com | Test User | authorized |
| `user-002` | hidden@privaterelay | User 2 | authorized |
| `revoked-user` | - | - | revoked |

### Session Configurations

| Session ID | Expiry | Refresh Token |
|------------|--------|---------------|
| `session-active` | +1 hour | valid |
| `session-expired` | -1 hour | valid |
| `session-no-refresh` | +1 hour | invalid |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 28 test cases | AI Agent |
