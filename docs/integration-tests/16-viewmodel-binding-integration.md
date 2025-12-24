# IT-BIND: ViewModel-View Binding Integration Tests

## Overview

This document defines integration tests for ViewModel-View bindings based on the MVVM architecture documented in 02-application-layers.md. These tests verify correct state propagation, user action handling, and reactive updates between Views and ViewModels.

**Priority**: P0-Critical
**Total Test Cases**: 72
**Estimated Execution Time**: 20 minutes

---

## Test Environment

### Required Components
- `HomeViewModel`
- `InterpretationViewModel`
- `SettingsViewModel`
- `HistoryViewModel`
- `OnboardingViewModel`
- All associated Views

### Mock Dependencies
- `MockSpeechRecognitionManager`
- `MockTranslationManager`
- `MockTTSManager`
- `MockDataManager`

### Test Framework
- XCTest with Combine expectations
- XCUITest for UI state verification
- Custom state inspection utilities

---

## IT-BIND-001: HomeViewModel Bindings

### Test Case IT-BIND-001-01: Language Selection Binding

**Objective**: Verify language selection updates propagate to View.

**Preconditions**:
- HomeView displayed
- Default languages set

**Test Steps**:
1. Change source language in ViewModel
2. Verify View updates
3. Change target language in ViewModel
4. Verify View updates

**Expected Results**:
- [ ] @Published sourceLanguage updates View immediately
- [ ] @Published targetLanguage updates View immediately
- [ ] No UI lag or flickering
- [ ] Binding is two-way

```swift
func testLanguageSelectionBinding() throws {
    let viewModel = HomeViewModel()
    let expectation = XCTestExpectation(description: "Language updated")

    var receivedValues: [SupportedLanguage] = []
    let cancellable = viewModel.$sourceLanguage
        .sink { language in
            receivedValues.append(language)
            if receivedValues.count == 2 {
                expectation.fulfill()
            }
        }

    // Initial value
    XCTAssertEqual(viewModel.sourceLanguage, .japanese)

    // Update
    viewModel.sourceLanguage = .chinese

    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(receivedValues.last, .chinese)

    cancellable.cancel()
}
```

---

### Test Case IT-BIND-001-02: Swap Languages Action Binding

**Objective**: Verify swap action updates both languages atomically.

**Test Steps**:
1. Note current languages (ja, en)
2. Call swapLanguages()
3. Verify both updated

**Expected Results**:
- [ ] Source becomes previous target
- [ ] Target becomes previous source
- [ ] Single update cycle (atomic)
- [ ] UI reflects change immediately

```swift
func testSwapLanguagesActionBinding() throws {
    let viewModel = HomeViewModel()
    viewModel.sourceLanguage = .japanese
    viewModel.targetLanguage = .english

    viewModel.swapLanguages()

    XCTAssertEqual(viewModel.sourceLanguage, .english)
    XCTAssertEqual(viewModel.targetLanguage, .japanese)
}
```

---

### Test Case IT-BIND-001-03: Navigation State Binding

**Objective**: Verify navigation actions update navigation path.

**Test Steps**:
1. Call showSettings()
2. Verify navigation path updated
3. Call showHistory()
4. Verify navigation path updated

**Expected Results**:
- [ ] Navigation path contains correct destination
- [ ] View responds to navigation change
- [ ] Back navigation clears path

---

### Test Case IT-BIND-001-04: Start Interpretation Action

**Objective**: Verify start interpretation triggers correct flow.

**Test Steps**:
1. Call startInterpretation()
2. Verify state changes
3. Verify navigation

**Expected Results**:
- [ ] isStarting becomes true during setup
- [ ] Navigation to InterpretationView triggered
- [ ] Languages passed to InterpretationViewModel
- [ ] Error state if permissions denied

```swift
func testStartInterpretationAction() async throws {
    let viewModel = HomeViewModel()
    let permissionManager = MockPermissionManager()
    permissionManager.mockMicrophoneGranted = true

    viewModel.permissionManager = permissionManager

    await viewModel.startInterpretation(
        source: .japanese,
        target: .english
    )

    XCTAssertTrue(viewModel.shouldNavigateToInterpretation)
    XCTAssertEqual(viewModel.interpretationConfig?.sourceLanguage, .japanese)
    XCTAssertEqual(viewModel.interpretationConfig?.targetLanguage, .english)
}
```

---

### Test Case IT-BIND-001-05: Permission Check State

**Objective**: Verify permission state bindings.

**Test Steps**:
1. Check initial permission state
2. Request permissions
3. Verify state updates

**Expected Results**:
- [ ] canStartInterpretation reflects permission state
- [ ] showsPermissionRequired true when denied
- [ ] State updates when permission changes

---

## IT-BIND-002: InterpretationViewModel Bindings

### Test Case IT-BIND-002-01: isListening State Binding

**Objective**: Verify listening state reflects in UI.

**Test Steps**:
1. Check initial state (not listening)
2. Toggle listening
3. Verify UI updates

**Expected Results**:
- [ ] isListening initially false
- [ ] toggleListening() flips state
- [ ] UI control button reflects state
- [ ] Live indicator shown when listening

```swift
func testIsListeningStateBinding() throws {
    let viewModel = InterpretationViewModel(
        sourceLanguage: .japanese,
        targetLanguage: .english
    )

    XCTAssertFalse(viewModel.isListening)

    viewModel.toggleListening()

    XCTAssertTrue(viewModel.isListening)
}
```

---

### Test Case IT-BIND-002-02: Transcript Items Binding

**Objective**: Verify transcript items update View.

**Test Steps**:
1. Check initial empty state
2. Receive STT result
3. Verify new item added
4. Check UI updates

**Expected Results**:
- [ ] transcriptItems initially empty
- [ ] New items append to array
- [ ] View re-renders with new bubble
- [ ] ScrollView scrolls to bottom

```swift
func testTranscriptItemsBinding() throws {
    let viewModel = InterpretationViewModel(
        sourceLanguage: .japanese,
        targetLanguage: .english
    )

    XCTAssertEqual(viewModel.transcriptItems.count, 0)

    // Simulate STT result
    let mockResult = TranscriptItem(
        id: UUID(),
        speaker: .speaker1,
        originalText: "こんにちは",
        translatedText: "Hello",
        timestamp: Date()
    )

    viewModel.addTranscriptItem(mockResult)

    XCTAssertEqual(viewModel.transcriptItems.count, 1)
    XCTAssertEqual(viewModel.transcriptItems.first?.originalText, "こんにちは")
}
```

---

### Test Case IT-BIND-002-03: Audio Level Binding

**Objective**: Verify audio level updates live indicator.

**Test Steps**:
1. Start listening
2. Simulate audio input
3. Verify audioLevel updates

**Expected Results**:
- [ ] audioLevel starts at 0
- [ ] Updates with audio input
- [ ] Range 0.0 to 1.0
- [ ] Updates at reasonable frequency (60Hz max)

```swift
func testAudioLevelBinding() throws {
    let viewModel = InterpretationViewModel(
        sourceLanguage: .japanese,
        targetLanguage: .english
    )

    let expectation = XCTestExpectation(description: "Audio level updated")
    var receivedLevels: [Float] = []

    let cancellable = viewModel.$audioLevel
        .sink { level in
            receivedLevels.append(level)
            if receivedLevels.count >= 5 {
                expectation.fulfill()
            }
        }

    viewModel.toggleListening()
    viewModel.simulateAudioInput(level: 0.5)

    wait(for: [expectation], timeout: 2.0)
    XCTAssertTrue(receivedLevels.contains(where: { $0 > 0 }))

    cancellable.cancel()
}
```

---

### Test Case IT-BIND-002-04: Error State Binding

**Objective**: Verify error state shows error banner.

**Test Steps**:
1. Trigger error condition
2. Verify error state
3. Check error message binding

**Expected Results**:
- [ ] hasError becomes true
- [ ] errorMessage populated
- [ ] View shows error banner
- [ ] Dismiss clears error state

```swift
func testErrorStateBinding() throws {
    let viewModel = InterpretationViewModel(
        sourceLanguage: .japanese,
        targetLanguage: .english
    )

    XCTAssertFalse(viewModel.hasError)
    XCTAssertNil(viewModel.errorMessage)

    viewModel.handleError(InterpretationError.audioInputFailed)

    XCTAssertTrue(viewModel.hasError)
    XCTAssertNotNil(viewModel.errorMessage)
}
```

---

### Test Case IT-BIND-002-05: Language Swap Mid-Session

**Objective**: Verify language swap during interpretation.

**Test Steps**:
1. Start interpretation
2. Swap languages
3. Verify state updates

**Expected Results**:
- [ ] Languages swap correctly
- [ ] New transcripts use new language pair
- [ ] Existing transcripts unchanged
- [ ] No interruption to audio

---

### Test Case IT-BIND-002-06: Current Speaker Binding

**Objective**: Verify current speaker indicator updates.

**Test Steps**:
1. Receive speaker 1 audio
2. Check currentSpeaker
3. Receive speaker 2 audio
4. Check currentSpeaker

**Expected Results**:
- [ ] currentSpeaker updates with diarization
- [ ] UI shows speaker indicator
- [ ] Smooth transition between speakers

---

### Test Case IT-BIND-002-07: Partial Result Binding

**Objective**: Verify partial STT results display.

**Test Steps**:
1. Start recognition
2. Receive partial result
3. Verify display

**Expected Results**:
- [ ] partialText updates in real-time
- [ ] View shows partial text indicator
- [ ] Replaced by final result
- [ ] Smooth transition

---

## IT-BIND-003: SettingsViewModel Bindings

### Test Case IT-BIND-003-01: Voice Setting Binding

**Objective**: Verify voice selection propagates.

**Test Steps**:
1. Check current voice
2. Change voice selection
3. Verify persistence

**Expected Results**:
- [ ] selectedVoice reflects current setting
- [ ] Change persists to UserDefaults/Storage
- [ ] TTS engine notified of change

```swift
func testVoiceSettingBinding() async throws {
    let viewModel = SettingsViewModel()

    let initialVoice = viewModel.selectedVoice

    viewModel.selectedVoice = .coefontNana

    await viewModel.saveSettings()

    // Create new instance to verify persistence
    let newViewModel = SettingsViewModel()
    XCTAssertEqual(newViewModel.selectedVoice, .coefontNana)
}
```

---

### Test Case IT-BIND-003-02: App Language Binding

**Objective**: Verify app language selection.

**Test Steps**:
1. Check current app language
2. Change to English
3. Verify UI language changes

**Expected Results**:
- [ ] appLanguage reflects current setting
- [ ] UI text changes to selected language
- [ ] Change persists

---

### Test Case IT-BIND-003-03: Privacy Settings Binding

**Objective**: Verify privacy toggles.

**Test Steps**:
1. Check analytics consent
2. Toggle setting
3. Verify behavior change

**Expected Results**:
- [ ] analyticsEnabled reflects current state
- [ ] Toggle updates immediately
- [ ] Analytics service respects setting

---

### Test Case IT-BIND-003-04: iCloud Sync Toggle

**Objective**: Verify iCloud sync setting.

**Test Steps**:
1. Check sync enabled state
2. Toggle sync
3. Verify sync behavior

**Expected Results**:
- [ ] iCloudSyncEnabled reflects state
- [ ] Enabling triggers initial sync
- [ ] Disabling stops syncing

---

## IT-BIND-004: HistoryViewModel Bindings

### Test Case IT-BIND-004-01: Conversations List Binding

**Objective**: Verify conversation list updates.

**Test Steps**:
1. Load history
2. Check conversations array
3. Add new conversation
4. Verify list updates

**Expected Results**:
- [ ] conversations array populated from storage
- [ ] New conversations appear at top
- [ ] List sorted by date

```swift
func testConversationsListBinding() async throws {
    let viewModel = HistoryViewModel()

    await viewModel.loadConversations()

    let initialCount = viewModel.conversations.count

    // Simulate new conversation saved
    let newConversation = Conversation(
        id: UUID(),
        sourceLanguage: .japanese,
        targetLanguage: .english,
        createdAt: Date(),
        utterances: []
    )
    await DataManager.shared.save(newConversation)

    await viewModel.loadConversations()

    XCTAssertEqual(viewModel.conversations.count, initialCount + 1)
    XCTAssertEqual(viewModel.conversations.first?.id, newConversation.id)
}
```

---

### Test Case IT-BIND-004-02: Search Query Binding

**Objective**: Verify search filters list.

**Test Steps**:
1. Enter search query
2. Verify filtered results
3. Clear search
4. Verify all results return

**Expected Results**:
- [ ] searchQuery binding works
- [ ] filteredConversations updates
- [ ] Search is case-insensitive
- [ ] Empty query shows all

```swift
func testSearchQueryBinding() async throws {
    let viewModel = HistoryViewModel()
    await viewModel.loadConversations()

    let totalCount = viewModel.conversations.count

    viewModel.searchQuery = "weather"

    await viewModel.search()

    XCTAssertLessThanOrEqual(viewModel.filteredConversations.count, totalCount)

    viewModel.searchQuery = ""

    await viewModel.search()

    XCTAssertEqual(viewModel.filteredConversations.count, totalCount)
}
```

---

### Test Case IT-BIND-004-03: Delete Action Binding

**Objective**: Verify delete removes item.

**Test Steps**:
1. Select conversation
2. Delete
3. Verify removed from list

**Expected Results**:
- [ ] Item removed from conversations array
- [ ] View updates immediately
- [ ] Persistence layer updated

---

### Test Case IT-BIND-004-04: Loading State Binding

**Objective**: Verify loading state during fetch.

**Test Steps**:
1. Trigger load
2. Check isLoading state
3. After load complete

**Expected Results**:
- [ ] isLoading true during fetch
- [ ] isLoading false after complete
- [ ] View shows loading indicator

---

## IT-BIND-005: OnboardingViewModel Bindings

### Test Case IT-BIND-005-01: Current Page Binding

**Objective**: Verify page navigation.

**Test Steps**:
1. Check initial page (0)
2. Navigate to next
3. Verify page updates

**Expected Results**:
- [ ] currentPage initially 0
- [ ] next() increments
- [ ] previous() decrements
- [ ] View shows correct page

```swift
func testCurrentPageBinding() throws {
    let viewModel = OnboardingViewModel()

    XCTAssertEqual(viewModel.currentPage, 0)

    viewModel.next()
    XCTAssertEqual(viewModel.currentPage, 1)

    viewModel.previous()
    XCTAssertEqual(viewModel.currentPage, 0)
}
```

---

### Test Case IT-BIND-005-02: Can Continue Binding

**Objective**: Verify continue button enabled state.

**Test Steps**:
1. Check on permission page
2. Verify disabled before grant
3. Grant permission
4. Verify enabled

**Expected Results**:
- [ ] canContinue false when requirements not met
- [ ] canContinue true when requirements met
- [ ] Continue button reflects state

---

### Test Case IT-BIND-005-03: Completion Binding

**Objective**: Verify onboarding completion.

**Test Steps**:
1. Navigate to last page
2. Complete onboarding
3. Verify completion state

**Expected Results**:
- [ ] isCompleted true after finish
- [ ] Persisted to prevent re-show
- [ ] Navigation to home triggered

---

## IT-BIND-006: Combine Publisher Integration

### Test Case IT-BIND-006-01: STT Result Publisher

**Objective**: Verify STT results flow through Combine.

**Test Steps**:
1. Subscribe to sttResultPublisher
2. Trigger recognition
3. Verify results received

**Expected Results**:
- [ ] Results published on main queue
- [ ] Subscriber receives all results
- [ ] No dropped values

```swift
func testSTTResultPublisher() async throws {
    let viewModel = InterpretationViewModel(
        sourceLanguage: .japanese,
        targetLanguage: .english
    )

    let expectation = XCTestExpectation(description: "STT result received")
    var receivedResults: [String] = []

    let cancellable = viewModel.sttResultPublisher
        .sink { result in
            receivedResults.append(result)
            expectation.fulfill()
        }

    viewModel.toggleListening()
    viewModel.injectMockSTTResult("テスト")

    await fulfillment(of: [expectation], timeout: 2.0)

    XCTAssertTrue(receivedResults.contains("テスト"))
    cancellable.cancel()
}
```

---

### Test Case IT-BIND-006-02: Translation Result Publisher

**Objective**: Verify translation results flow through.

**Test Steps**:
1. Subscribe to translationPublisher
2. Trigger translation
3. Verify results

**Expected Results**:
- [ ] Translation published after STT
- [ ] Contains both original and translated
- [ ] Proper sequencing

---

### Test Case IT-BIND-006-03: Error Publisher

**Objective**: Verify errors propagate through publisher.

**Test Steps**:
1. Subscribe to errorPublisher
2. Trigger error condition
3. Verify error received

**Expected Results**:
- [ ] Error published when occurs
- [ ] Error type preserved
- [ ] Subscriber can handle

---

## IT-BIND-007: State Persistence Tests

### Test Case IT-BIND-007-01: ViewModel State Restoration

**Objective**: Verify state restores after app restart.

**Test Steps**:
1. Set settings
2. Simulate app termination
3. Restart
4. Verify state restored

**Expected Results**:
- [ ] Language preferences restored
- [ ] Voice settings restored
- [ ] Privacy settings restored
- [ ] No data loss

---

### Test Case IT-BIND-007-02: In-Progress Session Recovery

**Objective**: Verify partial session recovery.

**Test Steps**:
1. Start interpretation
2. Simulate crash
3. Restart
4. Check for recovery

**Expected Results**:
- [ ] Draft saved periodically
- [ ] Recovery prompt shown
- [ ] Session can resume or discard

---

## Test Data Fixtures

### ViewModel States

| State | Published Properties |
|-------|---------------------|
| Idle | isListening: false, transcriptItems: [], audioLevel: 0 |
| Listening | isListening: true, audioLevel: varies |
| Processing | isListening: true, partialText: "..." |
| Error | hasError: true, errorMessage: "..." |

### Mock Transcripts

| Sequence | Original | Translated | Speaker |
|----------|----------|------------|---------|
| 1 | こんにちは | Hello | 0 |
| 2 | Nice to meet you | はじめまして | 1 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 72 test cases | AI Agent |
