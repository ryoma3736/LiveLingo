# IT-L10N: Localization UI Integration Tests

## Overview

This document defines integration tests for localization and internationalization based on the multi-language UI specifications in 05-ui-components.md. These tests verify correct text rendering, RTL support, date/time formatting, and language switching.

**Priority**: P1-High
**Total Test Cases**: 52
**Estimated Execution Time**: 18 minutes

---

## Test Environment

### Required Components
- `AppLanguageManager`
- `LocalizationBundle`
- All localized Views

### Supported Languages
- Japanese (ja) - Primary
- English (en) - Required
- Chinese Simplified (zh-Hans) - Required

### Mock Dependencies
- `MockLocalizationService`
- `MockDateFormatter`

### Test Framework
- XCUITest with locale override
- String comparison utilities
- Layout measurement tools

---

## IT-L10N-001: Language Selection Tests

### Test Case IT-L10N-001-01: Default Language Detection

**Objective**: Verify app uses device language by default.

**Preconditions**:
- Fresh install
- Device language set to Japanese

**Test Steps**:
1. Install app
2. Launch
3. Verify UI language

**Expected Results**:
- [ ] App launches in Japanese
- [ ] All UI text in Japanese
- [ ] No English fallback visible
- [ ] Correct date formatting

```swift
func testDefaultLanguageDetection() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)"]
    app.launch()

    // Check Japanese text
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertEqual(startButton.label, "通訳を開始")

    let historyButton = app.buttons["HistoryButton"]
    XCTAssertEqual(historyButton.label, "履歴")
}
```

---

### Test Case IT-L10N-001-02: Manual Language Change to English

**Objective**: Verify language can be changed to English.

**Test Steps**:
1. Open Settings
2. Change language to English
3. Verify UI updates

**Expected Results**:
- [ ] All UI text changes to English
- [ ] Navigation titles in English
- [ ] Buttons in English
- [ ] No Japanese text visible

```swift
func testManualLanguageChangeToEnglish() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)"]
    app.launch()

    // Navigate to settings
    app.buttons["SettingsButton"].tap()

    // Find language setting
    app.cells["AppLanguageSetting"].tap()

    // Select English
    app.buttons["English"].tap()

    // Back to home
    app.buttons["Back"].tap()
    app.buttons["Back"].tap()

    // Verify English
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertEqual(startButton.label, "Start Interpretation")
}
```

---

### Test Case IT-L10N-001-03: Manual Language Change to Chinese

**Objective**: Verify language can be changed to Chinese.

**Test Steps**:
1. Open Settings
2. Change language to Chinese
3. Verify UI updates

**Expected Results**:
- [ ] All UI text changes to Chinese
- [ ] Correct simplified characters
- [ ] No Japanese/English mixed
- [ ] Proper Chinese punctuation

```swift
func testManualLanguageChangeToChinese() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)"]
    app.launch()

    // Navigate to settings and change language
    app.buttons["SettingsButton"].tap()
    app.cells["AppLanguageSetting"].tap()
    app.buttons["中文"].tap()

    // Back to home
    app.buttons["Back"].tap()
    app.buttons["Back"].tap()

    // Verify Chinese
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertEqual(startButton.label, "开始翻译")
}
```

---

### Test Case IT-L10N-001-04: Language Persistence

**Objective**: Verify language choice persists across launches.

**Test Steps**:
1. Change language to English
2. Terminate app
3. Relaunch app
4. Verify language

**Expected Results**:
- [ ] Language persists
- [ ] No flash of default language
- [ ] UserDefaults correctly stored
- [ ] Consistent on next launch

---

### Test Case IT-L10N-001-05: Unsupported Language Fallback

**Objective**: Verify fallback for unsupported languages.

**Test Steps**:
1. Set device to unsupported language
2. Launch app
3. Check fallback

**Expected Results**:
- [ ] Falls back to English
- [ ] No missing strings
- [ ] No crashes
- [ ] Can still change language

---

## IT-L10N-002: String Localization Tests

### Test Case IT-L10N-002-01: All Strings Localized - Japanese

**Objective**: Verify all strings have Japanese translations.

**Test Steps**:
1. Set language to Japanese
2. Navigate all screens
3. Check for untranslated strings

**Expected Results**:
- [ ] No "key_name" format strings visible
- [ ] All buttons translated
- [ ] All labels translated
- [ ] All error messages translated

```swift
func testAllStringsLocalizedJapanese() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)"]
    app.launch()

    // Check for untranslated strings (look for underscore patterns)
    let allLabels = app.staticTexts.allElementsBoundByIndex.map { $0.label }

    for label in allLabels {
        XCTAssertFalse(label.contains("_"), "Found untranslated key: \(label)")
        XCTAssertFalse(label.hasPrefix("key."), "Found untranslated key: \(label)")
    }
}
```

---

### Test Case IT-L10N-002-02: All Strings Localized - English

**Objective**: Verify all strings have English translations.

**Test Steps**:
1. Set language to English
2. Navigate all screens
3. Check for untranslated strings

**Expected Results**:
- [ ] No Japanese characters in UI
- [ ] All strings in English
- [ ] Proper capitalization
- [ ] No key_name patterns

---

### Test Case IT-L10N-002-03: All Strings Localized - Chinese

**Objective**: Verify all strings have Chinese translations.

**Test Steps**:
1. Set language to Chinese
2. Navigate all screens
3. Check for untranslated strings

**Expected Results**:
- [ ] All strings in simplified Chinese
- [ ] No Japanese characters
- [ ] No traditional Chinese mix
- [ ] Proper Chinese grammar

---

### Test Case IT-L10N-002-04: Plural Forms

**Objective**: Verify plural forms handled correctly.

**Test Steps**:
1. Check strings with counts (0, 1, many)
2. Verify correct form used

**Expected Results**:
- [ ] Zero: "0 conversations" / "会話なし"
- [ ] One: "1 conversation" / "1件の会話"
- [ ] Many: "5 conversations" / "5件の会話"
- [ ] Localized plural rules

```swift
func testPluralForms() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)"]
    app.launch()

    app.buttons["HistoryButton"].tap()

    // Check different count displays
    // This depends on mock data setup
}
```

---

### Test Case IT-L10N-002-05: String Interpolation

**Objective**: Verify interpolated strings render correctly.

**Test Steps**:
1. Find strings with variables
2. Verify correct substitution
3. Check order in different languages

**Expected Results**:
- [ ] Variables substituted correctly
- [ ] Correct order for language
- [ ] No format string visible
- [ ] Numbers formatted correctly

---

## IT-L10N-003: Layout Adaptation Tests

### Test Case IT-L10N-003-01: Japanese Text Length Adaptation

**Objective**: Verify layout handles Japanese text length.

**Test Steps**:
1. Set language to Japanese
2. Check button widths
3. Check label truncation

**Expected Results**:
- [ ] Japanese text fits containers
- [ ] No truncation of important text
- [ ] Proper text wrapping
- [ ] Layout balanced

```swift
func testJapaneseTextLengthAdaptation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)"]
    app.launch()

    // Check start button not truncated
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertFalse(startButton.label.hasSuffix("..."))

    // Check settings items
    app.buttons["SettingsButton"].tap()
    let cells = app.cells.allElementsBoundByIndex
    for cell in cells {
        let label = cell.staticTexts.firstMatch.label
        XCTAssertFalse(label.hasSuffix("..."), "Cell text truncated: \(label)")
    }
}
```

---

### Test Case IT-L10N-003-02: English Text Length Adaptation

**Objective**: Verify layout handles English text length.

**Test Steps**:
1. Set language to English
2. Check all text containers
3. Verify no overflow

**Expected Results**:
- [ ] English text fits
- [ ] Buttons size appropriately
- [ ] Labels wrap correctly
- [ ] No clipping

---

### Test Case IT-L10N-003-03: Chinese Text Length Adaptation

**Objective**: Verify layout handles Chinese text length.

**Test Steps**:
1. Set language to Chinese
2. Check compact Chinese text
3. Verify proper spacing

**Expected Results**:
- [ ] Chinese characters display correctly
- [ ] Proper character spacing
- [ ] No awkward breaks
- [ ] Layout remains clean

---

### Test Case IT-L10N-003-04: Auto Layout Constraints

**Objective**: Verify constraints adapt to text.

**Test Steps**:
1. Switch between languages
2. Check for constraint warnings
3. Verify no breaking layouts

**Expected Results**:
- [ ] No unsatisfiable constraints
- [ ] No ambiguous layout
- [ ] Smooth transitions
- [ ] All content visible

---

## IT-L10N-004: Date and Time Formatting Tests

### Test Case IT-L10N-004-01: Japanese Date Format

**Objective**: Verify dates formatted in Japanese style.

**Test Steps**:
1. Set language to Japanese
2. Check date displays
3. Verify format

**Expected Results**:
- [ ] Date: 2024年12月24日
- [ ] Time: 14:30 (24-hour)
- [ ] Relative: "1時間前"
- [ ] Calendar: Japanese calendar support

```swift
func testJapaneseDateFormat() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    app.launch()

    app.buttons["HistoryButton"].tap()

    // Check a date cell
    let dateText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '年'")).firstMatch
    XCTAssertTrue(dateText.exists, "Should show Japanese date format")
}
```

---

### Test Case IT-L10N-004-02: English Date Format

**Objective**: Verify dates formatted in English style.

**Test Steps**:
1. Set language to English
2. Check date displays
3. Verify format

**Expected Results**:
- [ ] Date: December 24, 2024
- [ ] Time: 2:30 PM (12-hour)
- [ ] Relative: "1 hour ago"
- [ ] US format by default

---

### Test Case IT-L10N-004-03: Chinese Date Format

**Objective**: Verify dates formatted in Chinese style.

**Test Steps**:
1. Set language to Chinese
2. Check date displays
3. Verify format

**Expected Results**:
- [ ] Date: 2024年12月24日
- [ ] Time: 14:30 (24-hour)
- [ ] Relative: "1小时前"
- [ ] Simplified Chinese locale

---

### Test Case IT-L10N-004-04: Timestamp in Transcripts

**Objective**: Verify transcript timestamps localized.

**Test Steps**:
1. Create transcript with timestamp
2. Check display format
3. Switch languages

**Expected Results**:
- [ ] Time format matches locale
- [ ] Consistent across bubbles
- [ ] Readable format
- [ ] Relative time if recent

---

## IT-L10N-005: Number Formatting Tests

### Test Case IT-L10N-005-01: Decimal Separator

**Objective**: Verify correct decimal separator.

**Test Steps**:
1. Check audio level displays
2. Check percentage displays
3. Verify separator

**Expected Results**:
- [ ] Japanese/Chinese: "0.5"
- [ ] Some European locales: "0,5"
- [ ] Consistent throughout
- [ ] NumberFormatter used

---

### Test Case IT-L10N-005-02: Thousands Separator

**Objective**: Verify thousands separator.

**Test Steps**:
1. Check large number displays
2. Verify separator

**Expected Results**:
- [ ] Japanese: 1,000
- [ ] English: 1,000
- [ ] Chinese: 1,000
- [ ] Consistent formatting

---

## IT-L10N-006: Flag Icon Tests

### Test Case IT-L10N-006-01: Flag Icons SVG Rendering

**Objective**: Verify flag icons are SVG not emoji.

**Test Steps**:
1. Check language selector flags
2. Verify SVG rendering
3. Check for emoji flags

**Expected Results**:
- [ ] All flags use Image type
- [ ] No emoji flag sequences (🇯🇵)
- [ ] SVG scales correctly
- [ ] Consistent appearance

```swift
func testFlagIconsSVGRendering() throws {
    let app = XCUIApplication()
    app.launch()

    // Check flag images exist
    let sourceFlag = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'flag-'")).firstMatch
    XCTAssertTrue(sourceFlag.exists)

    // Verify it's not a text element (emoji would be text)
    XCTAssertTrue(sourceFlag.elementType == .image)
}
```

---

### Test Case IT-L10N-006-02: Flag Icon Accessibility

**Objective**: Verify flag icons have proper accessibility.

**Test Steps**:
1. Enable VoiceOver
2. Focus on flag
3. Verify announcement

**Expected Results**:
- [ ] Country name announced
- [ ] Not "flag emoji"
- [ ] Localized country names
- [ ] Clear identification

---

## IT-L10N-007: Error Message Localization Tests

### Test Case IT-L10N-007-01: Network Error Messages - Japanese

**Objective**: Verify network errors in Japanese.

**Test Steps**:
1. Set language to Japanese
2. Trigger network error
3. Check error message

**Expected Results**:
- [ ] Error message in Japanese
- [ ] Helpful guidance in Japanese
- [ ] Retry button in Japanese
- [ ] No English mixing

```swift
func testNetworkErrorMessagesJapanese() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(ja)", "--simulate-network-error"]
    app.launch()

    app.buttons["StartInterpretation"].tap()

    let errorMessage = app.staticTexts["ErrorMessage"]
    XCTAssertTrue(errorMessage.waitForExistence(timeout: 3.0))
    XCTAssertTrue(errorMessage.label.contains("接続"))
}
```

---

### Test Case IT-L10N-007-02: Permission Error Messages

**Objective**: Verify permission errors localized.

**Test Steps**:
1. Deny microphone permission
2. Attempt start
3. Check error message

**Expected Results**:
- [ ] Permission error localized
- [ ] Settings link text localized
- [ ] Clear instructions
- [ ] Matches system style

---

### Test Case IT-L10N-007-03: API Error Messages

**Objective**: Verify API errors localized.

**Test Steps**:
1. Trigger API error
2. Check error display
3. Verify localization

**Expected Results**:
- [ ] User-friendly message
- [ ] Technical details hidden
- [ ] Retry option localized
- [ ] Contact support localized

---

## IT-L10N-008: App Store Localization Tests

### Test Case IT-L10N-008-01: App Name Localization

**Objective**: Verify app name displays correctly.

**Test Steps**:
1. Check app name on home screen
2. Check in Settings
3. Verify localization

**Expected Results**:
- [ ] App name consistent
- [ ] Or localized variant
- [ ] Fits home screen
- [ ] No truncation

---

## Test Data Fixtures

### Localization Strings

| Key | Japanese | English | Chinese |
|-----|----------|---------|---------|
| start_interpretation | 通訳を開始 | Start Interpretation | 开始翻译 |
| stop_interpretation | 停止 | Stop | 停止 |
| history | 履歴 | History | 历史 |
| dictionary | 辞書 | Dictionary | 词典 |
| settings | 設定 | Settings | 设置 |
| select_language | 言語を選択 | Select Language | 选择语言 |
| swap_languages | 言語を入れ替え | Swap Languages | 切换语言 |

### Test Dates

| Date | Japanese | English | Chinese |
|------|----------|---------|---------|
| 2024-12-24 | 2024年12月24日 | December 24, 2024 | 2024年12月24日 |
| 14:30 | 14:30 | 2:30 PM | 14:30 |
| 1 hour ago | 1時間前 | 1 hour ago | 1小时前 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 52 test cases | AI Agent |
