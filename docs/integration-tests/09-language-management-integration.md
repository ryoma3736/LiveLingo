# IT-LNG: Language Management Integration Tests

## Overview

This document defines integration tests for language management based on workflows WF-LNG-001 through WF-LNG-005. These tests verify language pair selection, pack downloads, and preference persistence.

**Priority**: P2-Medium
**Total Test Cases**: 32
**Estimated Execution Time**: 10 minutes

---

## Test Environment

### Required Components
- `LanguageManager`
- `TranslationSession` (Apple)
- `LanguagePackDownloader`
- `UserDefaultsManager`
- `CloudKitManager`

### Mock Dependencies
- `MockTranslationSession`
- `MockDownloadManager`
- `MockUserDefaults`
- `MockCloudKit`

### Supported Languages
- Japanese (ja-JP)
- English (en-US, en-GB)
- Chinese (zh-CN, zh-TW)
- Korean (ko-KR)
- Spanish (es-ES)
- French (fr-FR)
- German (de-DE)

---

## WF-LNG-001: Language Pair Selection

### Test Case IT-LNG-001-01: Select Source and Target

**Objective**: Verify language pair can be selected.

**Preconditions**:
- Language packs available
- User signed in

**Test Steps**:
1. Open language selection
2. Select source = Japanese
3. Select target = English
4. Confirm selection

**Expected Results**:
- [ ] Both languages selected
- [ ] UI updated to show pair
- [ ] Translation ready
- [ ] Settings saved

```swift
func testLanguagePairSelection() async throws {
    let manager = LanguageManager()

    try await manager.setSourceLanguage(.japanese)
    try await manager.setTargetLanguage(.english)

    XCTAssertEqual(manager.sourceLanguage, .japanese)
    XCTAssertEqual(manager.targetLanguage, .english)
    XCTAssertTrue(manager.isPairValid)
}
```

---

### Test Case IT-LNG-001-02: Invalid Language Pair

**Objective**: Verify handling of unsupported language pair.

**Test Steps**:
1. Select rare source language
2. Select incompatible target
3. Verify error handling

**Expected Results**:
- [ ] Pair validation fails
- [ ] Error message shown
- [ ] Suggestion provided
- [ ] Previous selection maintained

---

### Test Case IT-LNG-001-03: Same Language Selection

**Objective**: Verify handling when source = target.

**Test Steps**:
1. Select Japanese as source
2. Attempt to select Japanese as target
3. Verify prevention

**Expected Results**:
- [ ] Selection prevented
- [ ] Message: "Source and target must differ"
- [ ] UI indicates invalid
- [ ] User must choose different

---

### Test Case IT-LNG-001-04: Language List Population

**Objective**: Verify language list loaded correctly.

**Test Steps**:
1. Open language picker
2. Verify available languages
3. Check metadata

**Expected Results**:
- [ ] All supported languages listed
- [ ] Native names shown (日本語, English)
- [ ] Download status indicated
- [ ] Sorted appropriately

---

### Test Case IT-LNG-001-05: Recent Languages

**Objective**: Verify recent languages shown first.

**Test Steps**:
1. Use Japanese → English
2. Use Chinese → English
3. Open language picker
4. Verify ordering

**Expected Results**:
- [ ] Recent pairs at top
- [ ] Chinese → English first
- [ ] Japanese → English second
- [ ] Quick selection available

---

### Test Case IT-LNG-001-06: Language Pair Validation

**Objective**: Verify translation availability check.

**Test Steps**:
1. Select language pair
2. Validate with Translation API
3. Confirm availability

**Expected Results**:
- [ ] API checked for support
- [ ] Available pairs marked
- [ ] Unavailable pairs indicated
- [ ] Download option if needed

---

## WF-LNG-002: Language Swap

### Test Case IT-LNG-002-01: Quick Swap

**Objective**: Verify one-tap language swap.

**Test Steps**:
1. Current: Japanese → English
2. Tap swap button
3. Verify: English → Japanese

**Expected Results**:
- [ ] Languages swapped instantly
- [ ] UI updated
- [ ] No configuration needed
- [ ] Ready for use

```swift
func testLanguageSwap() async throws {
    let manager = LanguageManager()
    manager.sourceLanguage = .japanese
    manager.targetLanguage = .english

    manager.swapLanguages()

    XCTAssertEqual(manager.sourceLanguage, .english)
    XCTAssertEqual(manager.targetLanguage, .japanese)
}
```

---

### Test Case IT-LNG-002-02: Swap During Active Session

**Objective**: Verify swap works during interpretation.

**Test Steps**:
1. Start interpretation
2. Tap swap
3. Verify new direction

**Expected Results**:
- [ ] Swap applied immediately
- [ ] Current audio continues
- [ ] New direction for next utterance
- [ ] No restart required

---

### Test Case IT-LNG-002-03: Swap with Unavailable Pack

**Objective**: Verify handling when reverse pack not available.

**Test Steps**:
1. Japanese → English (pack available)
2. Swap to English → Japanese
3. Pack not downloaded
4. Handle gracefully

**Expected Results**:
- [ ] Swap initiated
- [ ] Download prompt shown
- [ ] Option to use cloud translation
- [ ] User informed

---

### Test Case IT-LNG-002-04: Swap Animation

**Objective**: Verify swap animation smooth.

**Test Steps**:
1. Observe swap animation
2. Verify visual feedback

**Expected Results**:
- [ ] Animation 200-300ms
- [ ] Languages visually swap
- [ ] Direction indicator changes
- [ ] Professional feel

---

## WF-LNG-003: Language Pack Download

### Test Case IT-LNG-003-01: Initiate Pack Download

**Objective**: Verify language pack download flow.

**Test Steps**:
1. Select language pair needing download
2. Tap download button
3. Monitor progress
4. Verify completion

**Expected Results**:
- [ ] Download starts
- [ ] Progress shown (%)
- [ ] Completion notification
- [ ] Pack usable

```swift
func testLanguagePackDownload() async throws {
    let downloader = LanguagePackDownloader()

    let progressExpectation = expectation(description: "Progress updates")
    var progressUpdates: [Double] = []

    downloader.onProgress = { progress in
        progressUpdates.append(progress)
        if progress >= 1.0 {
            progressExpectation.fulfill()
        }
    }

    try await downloader.downloadPack(for: .japanese, to: .english)

    await fulfillment(of: [progressExpectation], timeout: 60.0)

    XCTAssertTrue(progressUpdates.contains { $0 >= 1.0 })
    XCTAssertTrue(downloader.isPackAvailable(source: .japanese, target: .english))
}
```

---

### Test Case IT-LNG-003-02: Download Progress Tracking

**Objective**: Verify progress updates received.

**Test Steps**:
1. Start download
2. Track progress callbacks
3. Verify updates

**Expected Results**:
- [ ] Progress 0% → 100%
- [ ] Updates at reasonable intervals
- [ ] UI progress bar accurate
- [ ] Pausable/resumable

---

### Test Case IT-LNG-003-03: Download Cancellation

**Objective**: Verify download can be cancelled.

**Test Steps**:
1. Start download
2. Cancel at 50%
3. Verify cleanup

**Expected Results**:
- [ ] Download stops
- [ ] Partial data cleaned
- [ ] No corrupt state
- [ ] Can restart later

---

### Test Case IT-LNG-003-04: Download Resume

**Objective**: Verify download resumes after interruption.

**Test Steps**:
1. Start download
2. Lose network at 50%
3. Restore network
4. Verify resume

**Expected Results**:
- [ ] Resume from 50%
- [ ] No re-download from start
- [ ] Completion successful
- [ ] Data integrity maintained

---

### Test Case IT-LNG-003-05: Insufficient Storage

**Objective**: Verify handling when storage low.

**Test Steps**:
1. Fill device storage
2. Attempt pack download
3. Verify error handling

**Expected Results**:
- [ ] Storage check before download
- [ ] Error: insufficient space
- [ ] Suggest cleanup
- [ ] No partial download

---

### Test Case IT-LNG-003-06: Pack Size Display

**Objective**: Verify pack size shown before download.

**Test Steps**:
1. View available packs
2. Check size display
3. Verify accuracy

**Expected Results**:
- [ ] Size shown (e.g., 150 MB)
- [ ] Accurate within 10%
- [ ] Cellular warning if large
- [ ] WiFi recommendation

---

## WF-LNG-004: UI Language Switch

### Test Case IT-LNG-004-01: Change App Language

**Objective**: Verify app UI language change.

**Test Steps**:
1. Current UI: English
2. Change to Japanese
3. Verify UI updates

**Expected Results**:
- [ ] All strings localized
- [ ] Menu items in Japanese
- [ ] Buttons relabeled
- [ ] Layout adjusted if needed

```swift
func testUILanguageChange() async throws {
    let localization = LocalizationManager.shared

    localization.setLanguage(.japanese)

    XCTAssertEqual(NSLocalizedString("settings", comment: ""), "設定")
    XCTAssertEqual(NSLocalizedString("start_interpretation", comment: ""), "通訳開始")
}
```

---

### Test Case IT-LNG-004-02: Language-Specific Layout

**Objective**: Verify RTL/LTR layout handling.

**Test Steps**:
1. Switch to Arabic (RTL)
2. Verify layout direction

**Expected Results**:
- [ ] Layout flips to RTL
- [ ] Text alignment correct
- [ ] Navigation consistent
- [ ] Icons mirrored if appropriate

---

### Test Case IT-LNG-004-03: System Language Fallback

**Objective**: Verify fallback to system language.

**Test Steps**:
1. Set app language to "System"
2. System language = French
3. Verify app uses French

**Expected Results**:
- [ ] System language detected
- [ ] App uses system language
- [ ] No manual config needed
- [ ] Updates with system changes

---

### Test Case IT-LNG-004-04: Unsupported UI Language

**Objective**: Verify handling of unsupported UI language.

**Test Steps**:
1. System language = Swahili (unsupported)
2. Launch app
3. Verify fallback

**Expected Results**:
- [ ] Falls back to English
- [ ] No crash
- [ ] User can change manually
- [ ] Graceful handling

---

## WF-LNG-005: Preference Persistence

### Test Case IT-LNG-005-01: UserDefaults Persistence

**Objective**: Verify language preferences saved locally.

**Test Steps**:
1. Set language pair
2. Restart app
3. Verify preferences restored

**Expected Results**:
- [ ] Source language saved
- [ ] Target language saved
- [ ] Restored on launch
- [ ] No default fallback

```swift
func testPreferencePersistence() throws {
    let manager = LanguageManager()
    manager.sourceLanguage = .chinese
    manager.targetLanguage = .japanese

    // Simulate restart
    let newManager = LanguageManager()
    newManager.loadPreferences()

    XCTAssertEqual(newManager.sourceLanguage, .chinese)
    XCTAssertEqual(newManager.targetLanguage, .japanese)
}
```

---

### Test Case IT-LNG-005-02: iCloud Sync

**Objective**: Verify preferences sync across devices.

**Test Steps**:
1. Set preferences on device A
2. Sign in on device B
3. Verify sync

**Expected Results**:
- [ ] Preferences synced via iCloud KV
- [ ] Device B receives settings
- [ ] Conflict resolution works
- [ ] Sync prompt (optional)

---

### Test Case IT-LNG-005-03: Preference Migration

**Objective**: Verify old preferences migrated on update.

**Test Steps**:
1. Old version format in storage
2. Update app
3. Launch
4. Verify migration

**Expected Results**:
- [ ] Old format detected
- [ ] Migration applied
- [ ] New format saved
- [ ] No data loss

---

### Test Case IT-LNG-005-04: Preference Reset

**Objective**: Verify preferences can be reset.

**Test Steps**:
1. Custom preferences set
2. Tap "Reset to Defaults"
3. Verify reset

**Expected Results**:
- [ ] All preferences reset
- [ ] Defaults restored
- [ ] Confirmation required
- [ ] Clean state

---

### Test Case IT-LNG-005-05: Preference Export/Import

**Objective**: Verify preferences can be exported.

**Test Steps**:
1. Export preferences
2. Modify preferences
3. Import from backup
4. Verify restoration

**Expected Results**:
- [ ] Export creates file
- [ ] Import parses correctly
- [ ] Preferences restored
- [ ] Validation performed

---

## Language-Specific Tests

### Test Case IT-LNG-SPEC-01: Japanese Input Handling

**Objective**: Verify Japanese-specific handling.

**Test Steps**:
1. Set source = Japanese
2. Test hiragana, katakana, kanji
3. Verify recognition

**Expected Results**:
- [ ] All scripts recognized
- [ ] Mixed text handled
- [ ] Romaji conversion (if needed)
- [ ] Proper segmentation

---

### Test Case IT-LNG-SPEC-02: Chinese Simplified/Traditional

**Objective**: Verify Chinese variant handling.

**Test Steps**:
1. Select Simplified Chinese
2. Verify recognition
3. Select Traditional Chinese
4. Verify different handling

**Expected Results**:
- [ ] Variants distinguished
- [ ] Correct character set
- [ ] Proper conversion
- [ ] Clear labeling

---

### Test Case IT-LNG-SPEC-03: Dialect Handling

**Objective**: Verify regional dialect support.

**Test Steps**:
1. Select English (US)
2. Process British English audio
3. Verify recognition

**Expected Results**:
- [ ] Cross-dialect recognition works
- [ ] Spelling variations handled
- [ ] Accent tolerance
- [ ] Quality acceptable

---

## Test Data Fixtures

### Language Pairs

| Source | Target | Pack Size | Offline |
|--------|--------|-----------|---------|
| Japanese | English | 150 MB | Yes |
| English | Japanese | 120 MB | Yes |
| Chinese | English | 180 MB | Yes |
| Korean | Japanese | 100 MB | Yes |

### Test Strings by Language

| Language | Test String | Expected |
|----------|-------------|----------|
| Japanese | こんにちは | Hello |
| Chinese | 你好 | Hello |
| Korean | 안녕하세요 | Hello |
| Spanish | Hola | Hello |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 32 test cases | AI Agent |
