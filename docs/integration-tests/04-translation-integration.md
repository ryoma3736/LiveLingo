# IT-TRN: Translation Integration Tests

## Overview

This document defines integration tests for the translation subsystem based on workflows WF-TRN-001 through WF-TRN-006. These tests verify translation accuracy, provider switching, streaming translation, and context management.

**Priority**: P0-Critical
**Total Test Cases**: 42
**Estimated Execution Time**: 15 minutes

---

## Test Environment

### Required Components
- `TranslationManager`
- `AppleTranslationProvider`
- `OpenAITranslationProvider`
- `AnthropicTranslationProvider`
- `ContextManager`
- `GlossaryManager`

### Mock Dependencies
- `MockTranslationSession` (Apple)
- `MockOpenAIClient`
- `MockAnthropicClient`
- `MockNetworkMonitor`

### Test Data
- Source texts in Japanese/English
- Expected translations
- Context conversation history
- Custom glossary terms

---

## WF-TRN-001: Apple Translation Framework

### Test Case IT-TRN-001-01: Basic Apple Translation

**Objective**: Verify Apple Translation API integration for JA→EN.

**Preconditions**:
- iOS 17.4+ (Translation framework available)
- Language pair downloaded
- Network not required (on-device)

**Test Steps**:
1. Initialize AppleTranslationProvider
2. Configure source=Japanese, target=English
3. Translate "こんにちは"
4. Verify result

**Expected Results**:
- [ ] Translation = "Hello" or equivalent
- [ ] Latency < 200ms (on-device)
- [ ] No network call made
- [ ] No error thrown

```swift
func testAppleTranslationBasic() async throws {
    let provider = AppleTranslationProvider()

    let result = try await provider.translate(
        text: "こんにちは",
        from: .japanese,
        to: .english
    )

    XCTAssertTrue(["Hello", "Hi", "Good day"].contains(result))
}
```

---

### Test Case IT-TRN-001-02: Apple Translation with Long Text

**Objective**: Verify handling of paragraph-length text.

**Test Steps**:
1. Prepare 500-character Japanese text
2. Translate to English
3. Verify complete translation

**Expected Results**:
- [ ] Full text translated
- [ ] No truncation
- [ ] Coherent output
- [ ] Latency < 1 second

---

### Test Case IT-TRN-001-03: Apple Translation Batch Processing

**Objective**: Verify multiple translations can run efficiently.

**Test Steps**:
1. Prepare 10 short sentences
2. Translate concurrently
3. Measure throughput

**Expected Results**:
- [ ] All 10 completed
- [ ] Total time < 2 seconds
- [ ] No rate limiting
- [ ] Results accurate

---

### Test Case IT-TRN-001-04: Apple Translation Language Pack Download

**Objective**: Verify language pack download flow.

**Test Steps**:
1. Check for missing language pack
2. Trigger download
3. Wait for completion
4. Verify usability

**Expected Results**:
- [ ] Download status trackable
- [ ] Progress reported
- [ ] Pack usable after download
- [ ] Offline translation works

---

### Test Case IT-TRN-001-05: Apple Translation Unavailable Fallback

**Objective**: Verify fallback when Apple Translation unavailable.

**Test Steps**:
1. Simulate Apple Translation unavailable
2. Attempt translation
3. Verify fallback provider used

**Expected Results**:
- [ ] Fallback triggered
- [ ] OpenAI or Anthropic used
- [ ] User notified
- [ ] Translation successful

---

## WF-TRN-002: OpenAI GPT Translation

### Test Case IT-TRN-002-01: OpenAI API Integration

**Objective**: Verify OpenAI API call for translation.

**Preconditions**:
- Valid API key configured
- Network available
- Rate limit not exceeded

**Test Steps**:
1. Initialize OpenAITranslationProvider
2. Configure with API key
3. Translate text
4. Verify response parsing

**Expected Results**:
- [ ] API call successful
- [ ] Response parsed correctly
- [ ] Translation accurate
- [ ] Tokens counted

```swift
func testOpenAITranslation() async throws {
    let provider = OpenAITranslationProvider(apiKey: testAPIKey)
    provider.model = "gpt-4o-mini"

    let result = try await provider.translate(
        text: "今日の天気はいいですね",
        from: .japanese,
        to: .english
    )

    XCTAssertTrue(result.lowercased().contains("weather"))
    XCTAssertTrue(result.lowercased().contains("nice") || result.lowercased().contains("good"))
}
```

---

### Test Case IT-TRN-002-02: OpenAI System Prompt Configuration

**Objective**: Verify custom system prompt applied.

**Test Steps**:
1. Configure formal translation style
2. Translate casual text
3. Verify formal output

**Expected Results**:
- [ ] System prompt included
- [ ] Output matches style
- [ ] Consistent behavior
- [ ] No prompt injection

---

### Test Case IT-TRN-002-03: OpenAI Rate Limit Handling

**Objective**: Verify graceful handling of rate limits.

**Test Steps**:
1. Simulate rate limit response (429)
2. Verify retry with backoff
3. Eventually succeed or fail gracefully

**Expected Results**:
- [ ] 429 detected
- [ ] Exponential backoff applied
- [ ] User informed of delay
- [ ] Eventually succeeds or falls back

---

### Test Case IT-TRN-002-04: OpenAI Token Counting

**Objective**: Verify token usage tracked correctly.

**Test Steps**:
1. Translate known text
2. Get token count
3. Compare to expected

**Expected Results**:
- [ ] Input tokens counted
- [ ] Output tokens counted
- [ ] Total within model limit
- [ ] Usage logged

---

### Test Case IT-TRN-002-05: OpenAI Error Response Handling

**Objective**: Verify handling of API errors.

**Test Steps**:
1. Simulate various error responses (400, 500)
2. Verify error handling
3. Check user message

**Expected Results**:
- [ ] Errors caught correctly
- [ ] User-friendly messages
- [ ] Retry available for transient
- [ ] Permanent errors escalated

---

## WF-TRN-003: Anthropic Claude Translation

### Test Case IT-TRN-003-01: Claude API Integration

**Objective**: Verify Anthropic Claude API integration.

**Preconditions**:
- Valid API key configured
- Network available

**Test Steps**:
1. Initialize AnthropicTranslationProvider
2. Configure with API key
3. Translate text
4. Verify response

**Expected Results**:
- [ ] API call successful (claude-3-haiku)
- [ ] Response parsed correctly
- [ ] Translation accurate
- [ ] Latency tracked

```swift
func testClaudeTranslation() async throws {
    let provider = AnthropicTranslationProvider(apiKey: testAPIKey)
    provider.model = "claude-3-haiku-20240307"

    let result = try await provider.translate(
        text: "ありがとうございます",
        from: .japanese,
        to: .english
    )

    XCTAssertTrue(result.lowercased().contains("thank"))
}
```

---

### Test Case IT-TRN-003-02: Claude Thinking Mode (Extended)

**Objective**: Verify extended thinking for complex translations.

**Test Steps**:
1. Enable thinking mode for complex text
2. Translate idiomatic expression
3. Verify quality improvement

**Expected Results**:
- [ ] Thinking mode activated
- [ ] Better nuance captured
- [ ] Higher latency acceptable
- [ ] User option available

---

### Test Case IT-TRN-003-03: Claude Context Window Usage

**Objective**: Verify large context handled correctly.

**Test Steps**:
1. Provide 10-turn conversation context
2. Translate new utterance
3. Verify context-aware translation

**Expected Results**:
- [ ] Full context sent
- [ ] Translation uses context
- [ ] No truncation errors
- [ ] Token limit managed

---

### Test Case IT-TRN-003-04: Claude vs OpenAI Quality Comparison

**Objective**: Compare translation quality between providers.

**Test Steps**:
1. Translate 10 test sentences with both
2. Evaluate accuracy
3. Record preferences

**Expected Results**:
- [ ] Both produce acceptable output
- [ ] Document quality differences
- [ ] Help inform provider selection
- [ ] Edge cases identified

---

## WF-TRN-004: Wait-k Streaming Translation

### Test Case IT-TRN-004-01: Streaming with k=3 Tokens

**Objective**: Verify streaming translation starts at k tokens.

**Test Steps**:
1. Configure Wait-k with k=3
2. Feed partial transcription
3. Verify translation trigger timing

**Expected Results**:
- [ ] Translation starts at 3 tokens
- [ ] First partial returned quickly
- [ ] Streaming updates received
- [ ] Final matches expected

```swift
func testWaitKStreaming() async throws {
    let manager = TranslationManager()
    manager.streamingConfig = .waitK(k: 3)

    var partialTranslations: [String] = []
    manager.onPartialTranslation = { text in
        partialTranslations.append(text)
    }

    // Simulate STT feeding tokens one by one
    await manager.feedToken("今日")
    await manager.feedToken("の")
    await manager.feedToken("天気")  // k=3 reached

    XCTAssertFalse(partialTranslations.isEmpty)

    await manager.feedToken("は")
    await manager.feedToken("いい")
    await manager.feedToken("です")
    await manager.feedToken("ね")
    await manager.finalize()

    XCTAssertTrue(partialTranslations.count > 1)
}
```

---

### Test Case IT-TRN-004-02: Streaming Coherence

**Objective**: Verify streaming translations are coherent.

**Test Steps**:
1. Stream translate long sentence
2. Collect all partials
3. Verify final coherent

**Expected Results**:
- [ ] Partials build logically
- [ ] No contradictions in updates
- [ ] Final is complete
- [ ] Grammar correct

---

### Test Case IT-TRN-004-03: Streaming Cancellation

**Objective**: Verify streaming can be cancelled mid-translation.

**Test Steps**:
1. Start streaming translation
2. Cancel after 2 partials
3. Verify cleanup

**Expected Results**:
- [ ] Stream cancelled immediately
- [ ] No more updates received
- [ ] Resources released
- [ ] Ready for next translation

---

### Test Case IT-TRN-004-04: Streaming with Provider Fallback

**Objective**: Verify streaming falls back if provider fails.

**Test Steps**:
1. Configure streaming with primary provider
2. Simulate provider failure mid-stream
3. Verify fallback activation

**Expected Results**:
- [ ] Failure detected
- [ ] Fallback provider activated
- [ ] Stream continues (or restarts)
- [ ] User notified

---

## WF-TRN-005: Context-Aware Translation

### Test Case IT-TRN-005-01: 10-Turn Context Window

**Objective**: Verify 10 previous turns used for context.

**Test Steps**:
1. Build 10-turn conversation history
2. Translate ambiguous pronoun
3. Verify resolution uses context

**Expected Results**:
- [ ] All 10 turns included
- [ ] Pronoun resolved correctly
- [ ] Context improves accuracy
- [ ] Oldest turn can be dropped

```swift
func testContextWindowUsage() async throws {
    let manager = TranslationManager()
    manager.contextWindowSize = 10

    // Build context
    for i in 1...10 {
        manager.addToContext("Turn \(i) content", speaker: i % 2 == 0 ? .a : .b)
    }

    // Translate with pronoun referring to earlier context
    let result = try await manager.translate(
        text: "彼はどこにいますか",  // "Where is he?"
        from: .japanese,
        to: .english
    )

    // Should resolve "he" based on context
    XCTAssertTrue(result.lowercased().contains("he"))
}
```

---

### Test Case IT-TRN-005-02: Context Reset on New Session

**Objective**: Verify context clears on new session.

**Test Steps**:
1. Build context in session 1
2. End session
3. Start new session
4. Verify context empty

**Expected Results**:
- [ ] Context cleared
- [ ] New session isolated
- [ ] No cross-session leakage
- [ ] Performance optimal

---

### Test Case IT-TRN-005-03: Context Memory Management

**Objective**: Verify context doesn't grow unbounded.

**Test Steps**:
1. Add 100 turns to context
2. Verify oldest dropped
3. Check memory usage

**Expected Results**:
- [ ] Only 10 turns retained
- [ ] FIFO eviction
- [ ] Memory stable
- [ ] Performance maintained

---

### Test Case IT-TRN-005-04: Context with Speaker Labels

**Objective**: Verify speaker labels preserved in context.

**Test Steps**:
1. Add context with speaker A and B
2. Translate new utterance
3. Verify translation considers speaker

**Expected Results**:
- [ ] Speaker labels included
- [ ] Translation considers speaker
- [ ] Formal/informal adjusted
- [ ] Pronouns correct

---

## WF-TRN-006: Glossary Application

### Test Case IT-TRN-006-01: Custom Term Replacement

**Objective**: Verify glossary terms applied during translation.

**Test Steps**:
1. Add glossary: "LiveLingo" → "LiveLingo" (no translate)
2. Translate text containing "LiveLingo"
3. Verify term preserved

**Expected Results**:
- [ ] "LiveLingo" unchanged
- [ ] Surrounding text translated
- [ ] Case preserved
- [ ] Multiple occurrences handled

```swift
func testGlossaryApplication() async throws {
    let manager = TranslationManager()
    manager.glossary.add(term: "LiveLingo", translation: "LiveLingo")
    manager.glossary.add(term: "会社名", translation: "Company Name")

    let result = try await manager.translate(
        text: "LiveLingoは素晴らしいアプリです",
        from: .japanese,
        to: .english
    )

    XCTAssertTrue(result.contains("LiveLingo"))
}
```

---

### Test Case IT-TRN-006-02: Technical Terminology Glossary

**Objective**: Verify technical terms translated consistently.

**Test Steps**:
1. Add technical glossary terms
2. Translate technical document
3. Verify consistent translation

**Expected Results**:
- [ ] Terms matched consistently
- [ ] Technical accuracy maintained
- [ ] Domain-specific translations
- [ ] User-editable glossary

---

### Test Case IT-TRN-006-03: Glossary Priority Over Model

**Objective**: Verify glossary overrides model's default.

**Test Steps**:
1. Add glossary that contradicts model default
2. Translate text
3. Verify glossary wins

**Expected Results**:
- [ ] Glossary term used
- [ ] Model default overridden
- [ ] Conflict logged
- [ ] User informed

---

### Test Case IT-TRN-006-04: Glossary Import/Export

**Objective**: Verify glossary can be imported/exported.

**Test Steps**:
1. Export current glossary
2. Clear glossary
3. Import from file
4. Verify terms restored

**Expected Results**:
- [ ] Export produces valid JSON
- [ ] Import parses correctly
- [ ] All terms restored
- [ ] Format documented

---

### Test Case IT-TRN-006-05: Glossary with Regex Patterns

**Objective**: Verify pattern-based glossary matching.

**Test Steps**:
1. Add regex pattern (e.g., email addresses)
2. Translate text with email
3. Verify pattern preserved

**Expected Results**:
- [ ] Regex matched
- [ ] Email address preserved
- [ ] Complex patterns work
- [ ] Performance acceptable

---

## Provider Switching

### Test Case IT-TRN-SWITCH-01: Primary to Fallback Transition

**Objective**: Verify seamless provider switching.

**Test Steps**:
1. Use Apple Translation as primary
2. Simulate unavailability
3. Verify OpenAI takes over
4. Return to Apple when available

**Expected Results**:
- [ ] Transition < 500ms
- [ ] No lost translations
- [ ] User notified
- [ ] Metrics tracked

---

### Test Case IT-TRN-SWITCH-02: User-Selected Provider

**Objective**: Verify user can choose provider.

**Test Steps**:
1. User selects OpenAI in settings
2. Verify OpenAI used
3. Change to Claude
4. Verify Claude used

**Expected Results**:
- [ ] Selection persisted
- [ ] Provider changed immediately
- [ ] Fallback still works
- [ ] UI reflects selection

---

### Test Case IT-TRN-SWITCH-03: Provider Quality Metrics

**Objective**: Verify quality metrics tracked per provider.

**Test Steps**:
1. Translate with each provider
2. Collect latency, accuracy metrics
3. Compare providers

**Expected Results**:
- [ ] Latency tracked
- [ ] Error rate tracked
- [ ] Quality score available
- [ ] Comparison dashboard

---

## Translation Cache

### Test Case IT-TRN-CACHE-01: Cache Hit Performance

**Objective**: Verify cached translations returned instantly.

**Test Steps**:
1. Translate text
2. Translate same text again
3. Measure second latency

**Expected Results**:
- [ ] Second request < 10ms
- [ ] Same result returned
- [ ] Cache key correct
- [ ] No API call made

---

### Test Case IT-TRN-CACHE-02: Cache Invalidation

**Objective**: Verify cache invalidated when appropriate.

**Test Steps**:
1. Translate with glossary A
2. Change glossary
3. Translate same text
4. Verify new translation

**Expected Results**:
- [ ] Old cache invalid
- [ ] New translation fetched
- [ ] Cache key includes glossary version
- [ ] Correctness maintained

---

### Test Case IT-TRN-CACHE-03: Cache Size Limit

**Objective**: Verify cache respects size limit.

**Test Steps**:
1. Fill cache to limit
2. Add new entries
3. Verify LRU eviction

**Expected Results**:
- [ ] Oldest entries evicted
- [ ] Size limit respected
- [ ] Memory stable
- [ ] Hit rate tracked

---

## Test Data Fixtures

### Source Texts

| ID | Japanese | Expected English | Category |
|----|----------|------------------|----------|
| `simple_01` | こんにちは | Hello | Greeting |
| `formal_01` | よろしくお願いいたします | Nice to meet you (formal) | Formal |
| `idiom_01` | 猫の手も借りたい | I'm extremely busy | Idiom |
| `tech_01` | クラウドコンピューティング | Cloud computing | Technical |
| `long_01` | (500 char paragraph) | (Paragraph) | Long |

### Glossary Terms

| Source | Target | Category |
|--------|--------|----------|
| LiveLingo | LiveLingo | Brand |
| API | API | Technical |
| 音声認識 | Speech Recognition | Feature |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 42 test cases | AI Agent |
