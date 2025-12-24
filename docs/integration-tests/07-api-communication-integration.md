# IT-API: API Communication Integration Tests

## Overview

This document defines integration tests for API communication based on workflows WF-API-001 through WF-API-005. These tests verify authentication, retry logic, rate limiting, and caching mechanisms.

**Priority**: P1-High
**Total Test Cases**: 38
**Estimated Execution Time**: 12 minutes

---

## Test Environment

### Required Components
- `APIClient`
- `AuthenticationManager`
- `RetryHandler`
- `RateLimiter`
- `NetworkMonitor`
- `ResponseCache`

### Mock Dependencies
- `MockURLSession`
- `MockNWPathMonitor`
- `MockKeychain`

### External Services
- CoeFont API (voice synthesis)
- OpenAI API (translation)
- Anthropic API (translation)

---

## WF-API-001: HMAC-SHA256 Authentication

### Test Case IT-API-001-01: CoeFont Signature Generation

**Objective**: Verify HMAC-SHA256 signature generated correctly.

**Preconditions**:
- Valid CoeFont credentials in Keychain

**Test Steps**:
1. Load credentials from Keychain
2. Create request body
3. Generate timestamp
4. Calculate HMAC-SHA256
5. Verify signature format

**Expected Results**:
- [ ] Credentials loaded securely
- [ ] Timestamp in ISO8601 format
- [ ] Signature matches expected hash
- [ ] Headers formatted correctly

```swift
func testHMACSHA256SignatureGeneration() throws {
    let auth = CoeFontAuthenticator(
        accessKey: "test-access-key",
        clientSecret: "test-client-secret"
    )

    let requestBody = """
    {"coefont":"voice-id","text":"こんにちは"}
    """
    let timestamp = "2024-12-24T12:00:00Z"

    let signature = auth.generateSignature(
        body: requestBody,
        timestamp: timestamp
    )

    // Verify signature is 64 character hex string (SHA256)
    XCTAssertEqual(signature.count, 64)
    XCTAssertTrue(signature.allSatisfy { $0.isHexDigit })

    // Verify deterministic
    let signature2 = auth.generateSignature(body: requestBody, timestamp: timestamp)
    XCTAssertEqual(signature, signature2)
}
```

---

### Test Case IT-API-001-02: Authentication Header Construction

**Objective**: Verify X-Coefont-* headers set correctly.

**Test Steps**:
1. Generate authentication
2. Construct headers
3. Verify header names and values

**Expected Results**:
- [ ] X-Coefont-Date header present
- [ ] X-Coefont-Content header present (body hash)
- [ ] Authorization header with signature
- [ ] Content-Type = application/json

---

### Test Case IT-API-001-03: Invalid Credentials Handling

**Objective**: Verify handling of 401 Unauthorized response.

**Test Steps**:
1. Configure with invalid credentials
2. Make API request
3. Observe error handling

**Expected Results**:
- [ ] 401 response detected
- [ ] Clear error message
- [ ] Prompt for credential update
- [ ] No retry (credentials issue)

---

### Test Case IT-API-001-04: Timestamp Drift Handling

**Objective**: Verify handling of clock skew.

**Test Steps**:
1. Simulate system time 10 minutes behind
2. Make authenticated request
3. Observe response

**Expected Results**:
- [ ] Request may fail (timestamp too old)
- [ ] Error message about time
- [ ] Suggest time correction
- [ ] Graceful degradation

---

### Test Case IT-API-001-05: Credential Rotation

**Objective**: Verify credentials can be updated.

**Test Steps**:
1. Make request with old credentials
2. Update credentials in settings
3. Make request with new credentials

**Expected Results**:
- [ ] Old credentials work initially
- [ ] Update saves to Keychain
- [ ] New credentials used
- [ ] No service interruption

---

## WF-API-002: Exponential Backoff Retry

### Test Case IT-API-002-01: Single Retry Success

**Objective**: Verify retry succeeds after transient failure.

**Test Steps**:
1. Configure mock to fail first request
2. Succeed on second request
3. Verify retry behavior

**Expected Results**:
- [ ] First request fails
- [ ] Wait 1 second
- [ ] Second request sent
- [ ] Success returned

```swift
func testExponentialBackoffRetry() async throws {
    let mockSession = MockURLSession()
    mockSession.responses = [
        .failure(URLError(.timedOut)),
        .success(validResponse)
    ]

    let client = APIClient(session: mockSession)
    client.retryConfig = .exponentialBackoff(
        initialDelay: 1.0,
        multiplier: 2.0,
        maxRetries: 3
    )

    let startTime = CFAbsoluteTimeGetCurrent()
    let result = try await client.request(endpoint: testEndpoint)
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    XCTAssertNotNil(result)
    XCTAssertGreaterThanOrEqual(duration, 1.0) // At least 1 second delay
    XCTAssertEqual(mockSession.requestCount, 2)
}
```

---

### Test Case IT-API-002-02: Backoff Timing Verification

**Objective**: Verify correct delay progression (1s, 2s, 4s).

**Test Steps**:
1. Configure mock to fail 3 times
2. Measure delays between retries
3. Verify progression

**Expected Results**:
- [ ] First delay ~1 second
- [ ] Second delay ~2 seconds
- [ ] Third delay ~4 seconds
- [ ] Jitter applied (±10%)

---

### Test Case IT-API-002-03: Max Retries Exhausted

**Objective**: Verify behavior when all retries fail.

**Test Steps**:
1. Configure mock to always fail
2. Set maxRetries = 3
3. Observe final behavior

**Expected Results**:
- [ ] 3 retry attempts made
- [ ] Total wait ~7 seconds (1+2+4)
- [ ] Error thrown after last
- [ ] User notified

---

### Test Case IT-API-002-04: Max Delay Cap (10s)

**Objective**: Verify delay doesn't exceed maximum.

**Test Steps**:
1. Configure maxDelay = 10 seconds
2. Fail enough to exceed cap
3. Verify delay capped

**Expected Results**:
- [ ] Delays increase up to 10s
- [ ] Never exceed 10s
- [ ] Retries continue at cap
- [ ] Eventually succeed or fail

---

### Test Case IT-API-002-05: Non-Retryable Errors

**Objective**: Verify certain errors skip retry.

**Test Steps**:
1. Return 400 Bad Request
2. Verify no retry
3. Return 401 Unauthorized
4. Verify no retry

**Expected Results**:
- [ ] 400 not retried (client error)
- [ ] 401 not retried (auth error)
- [ ] 403 not retried
- [ ] 5xx errors are retried

---

### Test Case IT-API-002-06: Retry with Updated Request

**Objective**: Verify request can be modified on retry.

**Test Steps**:
1. First request fails with specific error
2. Retry handler modifies request
3. Verify modified request sent

**Expected Results**:
- [ ] Original request captured
- [ ] Modification applied
- [ ] New request reflects changes
- [ ] Success on modified request

---

## WF-API-003: Rate Limiting (Token Bucket)

### Test Case IT-API-003-01: Token Bucket Basic Operation

**Objective**: Verify token bucket limits request rate.

**Test Steps**:
1. Configure bucket: 10 tokens, 1 token/second
2. Make 10 rapid requests
3. Attempt 11th request
4. Verify rate limiting

**Expected Results**:
- [ ] First 10 requests proceed
- [ ] 11th request waits
- [ ] Token regenerates after 1s
- [ ] 11th request completes

```swift
func testTokenBucketRateLimiting() async throws {
    let limiter = RateLimiter(
        maxTokens: 10,
        refillRate: 1.0 // 1 token per second
    )

    // Consume all tokens
    for _ in 1...10 {
        XCTAssertTrue(limiter.tryAcquire())
    }

    // 11th should fail (no tokens)
    XCTAssertFalse(limiter.tryAcquire())

    // Wait for refill
    try await Task.sleep(nanoseconds: 1_500_000_000)

    // Should have 1 token now
    XCTAssertTrue(limiter.tryAcquire())
}
```

---

### Test Case IT-API-003-02: Multiple Endpoint Limits

**Objective**: Verify separate limits for different endpoints.

**Test Steps**:
1. Configure limits: CoeFont=10/min, OpenAI=50/min
2. Hit CoeFont limit
3. Verify OpenAI still available

**Expected Results**:
- [ ] CoeFont limited at 10
- [ ] OpenAI continues up to 50
- [ ] Limits independent
- [ ] Status trackable

---

### Test Case IT-API-003-03: Rate Limit 429 Response Handling

**Objective**: Verify handling of server-side rate limit.

**Test Steps**:
1. Mock returns 429 with Retry-After header
2. Observe client behavior
3. Verify retry timing

**Expected Results**:
- [ ] 429 detected
- [ ] Retry-After header respected
- [ ] Client waits specified time
- [ ] Retry succeeds

---

### Test Case IT-API-003-04: Burst Allowance

**Objective**: Verify burst requests allowed up to limit.

**Test Steps**:
1. Configure burst limit = 20
2. Make 20 simultaneous requests
3. Verify all complete

**Expected Results**:
- [ ] All 20 proceed (burst)
- [ ] No immediate limiting
- [ ] Tokens consumed
- [ ] Next batch must wait

---

### Test Case IT-API-003-05: Rate Limit User Feedback

**Objective**: Verify user informed of rate limiting.

**Test Steps**:
1. Hit rate limit
2. Verify UI feedback
3. Wait for recovery
4. Verify feedback clears

**Expected Results**:
- [ ] Message shown to user
- [ ] Wait time displayed
- [ ] Auto-retry when available
- [ ] Message clears on success

---

## WF-API-004: Offline Detection

### Test Case IT-API-004-01: Network Path Monitoring

**Objective**: Verify network status detected via NWPathMonitor.

**Test Steps**:
1. Start network monitoring
2. Simulate network loss
3. Verify offline state detected

**Expected Results**:
- [ ] Monitor started
- [ ] Offline detected within 1s
- [ ] State change callback fired
- [ ] UI updated

```swift
func testNetworkPathMonitoring() async throws {
    let monitor = NetworkMonitor()

    var statusChanges: [Bool] = []
    monitor.onStatusChange = { isConnected in
        statusChanges.append(isConnected)
    }

    monitor.start()

    // Simulate going offline
    monitor.simulateOffline()
    try await Task.sleep(nanoseconds: 100_000_000)

    XCTAssertFalse(monitor.isConnected)
    XCTAssertTrue(statusChanges.contains(false))
}
```

---

### Test Case IT-API-004-02: Offline Banner Display

**Objective**: Verify offline banner shown in UI.

**Test Steps**:
1. Go offline
2. Verify banner appears
3. Go online
4. Verify banner dismisses

**Expected Results**:
- [ ] Banner appears promptly
- [ ] Message: "No internet connection"
- [ ] Dismisses on reconnect
- [ ] Animation smooth

---

### Test Case IT-API-004-03: Request Queueing When Offline

**Objective**: Verify requests queued during offline.

**Test Steps**:
1. Go offline
2. Make API request
3. Go online
4. Verify request completes

**Expected Results**:
- [ ] Request queued (not failed)
- [ ] User informed of queueing
- [ ] Sent when online
- [ ] Result returned

---

### Test Case IT-API-004-04: Offline Fallback Activation

**Objective**: Verify offline services activated.

**Test Steps**:
1. Go offline
2. Request translation
3. Verify offline translation used

**Expected Results**:
- [ ] Apple Translation (offline) used
- [ ] User informed of mode
- [ ] Quality may differ
- [ ] Core function works

---

### Test Case IT-API-004-05: Connection Quality Monitoring

**Objective**: Verify connection quality detected.

**Test Steps**:
1. Monitor on WiFi
2. Switch to cellular
3. Detect quality change
4. Adjust behavior

**Expected Results**:
- [ ] WiFi detected as high quality
- [ ] Cellular detected as lower
- [ ] Behavior adjusted (e.g., prefer local)
- [ ] User can override

---

## WF-API-005: Response Caching

### Test Case IT-API-005-01: LRU Cache Basic Operation

**Objective**: Verify LRU cache stores and retrieves.

**Test Steps**:
1. Make request
2. Cache response
3. Make same request
4. Verify cache hit

**Expected Results**:
- [ ] Response cached
- [ ] Cache key correct
- [ ] Second request from cache
- [ ] No network call

```swift
func testResponseCaching() async throws {
    let cache = ResponseCache(maxSize: 100, ttl: 3600)
    let client = APIClient(cache: cache)

    // First request - network
    let response1 = try await client.request(endpoint: testEndpoint)
    XCTAssertEqual(cache.hitCount, 0)

    // Second request - cache
    let response2 = try await client.request(endpoint: testEndpoint)
    XCTAssertEqual(cache.hitCount, 1)

    XCTAssertEqual(response1, response2)
}
```

---

### Test Case IT-API-005-02: Cache TTL Expiration (1 Hour)

**Objective**: Verify cache entries expire after TTL.

**Test Steps**:
1. Cache response
2. Wait for TTL expiration (simulate)
3. Request same endpoint
4. Verify network request made

**Expected Results**:
- [ ] Entry cached initially
- [ ] Entry expires after 1 hour
- [ ] Stale entry not returned
- [ ] Fresh data fetched

---

### Test Case IT-API-005-03: Cache Invalidation

**Objective**: Verify cache can be manually invalidated.

**Test Steps**:
1. Cache multiple responses
2. Invalidate specific entry
3. Verify entry removed
4. Other entries intact

**Expected Results**:
- [ ] Specific entry removed
- [ ] Other entries preserved
- [ ] Next request fetches fresh
- [ ] Invalidation by key works

---

### Test Case IT-API-005-04: Cache Size Limit

**Objective**: Verify cache respects size limit.

**Test Steps**:
1. Set cache max size = 100
2. Add 120 entries
3. Verify LRU eviction

**Expected Results**:
- [ ] 20 oldest entries evicted
- [ ] Most recent 100 retained
- [ ] Size limit respected
- [ ] Memory bounded

---

### Test Case IT-API-005-05: Cache Hit Rate Tracking

**Objective**: Verify cache statistics tracked.

**Test Steps**:
1. Make 100 requests (50 unique)
2. Get cache statistics
3. Verify hit rate

**Expected Results**:
- [ ] Hit count = ~50
- [ ] Miss count = ~50
- [ ] Hit rate = ~50%
- [ ] Stats reportable

---

### Test Case IT-API-005-06: Cache with Query Parameters

**Objective**: Verify different queries cached separately.

**Test Steps**:
1. Request with param A
2. Request with param B
3. Request with param A again

**Expected Results**:
- [ ] A and B cached separately
- [ ] Third request hits A's cache
- [ ] Correct response for each
- [ ] No cross-contamination

---

## Error Handling

### Test Case IT-API-ERR-01: Network Timeout

**Objective**: Verify timeout handling.

**Test Steps**:
1. Set timeout = 5 seconds
2. Mock slow response (10s)
3. Verify timeout

**Expected Results**:
- [ ] Request times out at 5s
- [ ] Timeout error thrown
- [ ] Retry triggered
- [ ] User notified if retries fail

---

### Test Case IT-API-ERR-02: Malformed Response

**Objective**: Verify handling of invalid JSON.

**Test Steps**:
1. Mock returns invalid JSON
2. Attempt to decode
3. Verify error handling

**Expected Results**:
- [ ] Decode error thrown
- [ ] Error logged
- [ ] Retry may help (transient)
- [ ] User sees friendly message

---

### Test Case IT-API-ERR-03: Server Error 500

**Objective**: Verify handling of server errors.

**Test Steps**:
1. Mock returns 500
2. Observe retry behavior
3. Verify fallback

**Expected Results**:
- [ ] Retry with backoff
- [ ] Fallback if retries fail
- [ ] Error logged with details
- [ ] User notified

---

## Test Data Fixtures

### Mock Responses

| Endpoint | Success Response | Error Response |
|----------|------------------|----------------|
| `/v1/speech` | Audio data (wav) | 400: Invalid text |
| `/v1/translate` | { translation: "..." } | 429: Rate limited |
| `/v1/auth` | { token: "..." } | 401: Invalid credentials |

### Rate Limit Configurations

| API | Requests/min | Burst | Retry-After |
|-----|--------------|-------|-------------|
| CoeFont | 60 | 10 | 60s |
| OpenAI | 60 | 20 | 30s |
| Anthropic | 60 | 15 | 30s |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 38 test cases | AI Agent |
