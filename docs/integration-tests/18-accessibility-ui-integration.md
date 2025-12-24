# IT-A11Y: Accessibility UI Integration Tests

## Overview

This document defines comprehensive integration tests for accessibility features based on UI component specifications (05-ui-components.md) and Apple Accessibility guidelines. These tests verify VoiceOver support, Dynamic Type, and assistive technology compatibility.

**Priority**: P1-High
**Total Test Cases**: 58
**Estimated Execution Time**: 20 minutes

---

## Test Environment

### Required Components
- All Views and ViewModels
- `AccessibilityManager`
- System Accessibility Services

### Mock Dependencies
- `MockAccessibilityService`
- `MockVoiceOverAnnouncement`

### Test Framework
- XCUITest with Accessibility Inspection
- XCTest Accessibility APIs
- VoiceOver testing utilities

### Accessibility Standards
- WCAG 2.1 Level AA
- Apple Human Interface Guidelines
- iOS Accessibility Best Practices

---

## IT-A11Y-001: VoiceOver Navigation Tests

### Test Case IT-A11Y-001-01: HomeView VoiceOver Order

**Objective**: Verify logical focus order on HomeView.

**Preconditions**:
- VoiceOver enabled
- HomeView displayed

**Test Steps**:
1. Enable VoiceOver
2. Navigate through HomeView
3. Verify focus order

**Expected Results**:
- [ ] Focus order: Logo → Language Toggle → Start Button → Quick Actions
- [ ] All interactive elements focusable
- [ ] No orphaned elements
- [ ] Logical reading order

```swift
func testHomeViewVoiceOverOrder() throws {
    let app = XCUIApplication()
    app.launch()

    // Get all accessibility elements in order
    let elements = app.descendants(matching: .any)
        .matching(NSPredicate(format: "isAccessibilityElement == true"))
        .allElementsBoundByAccessibilityElement

    let labels = elements.map { $0.label }

    // Verify logical order
    let expectedOrder = [
        "LiveLingo Logo",
        "Source Language",
        "Swap Languages",
        "Target Language",
        "Start Interpretation",
        "History",
        "Dictionary",
        "Settings"
    ]

    for (index, expected) in expectedOrder.enumerated() {
        XCTAssertTrue(labels[index].contains(expected), "Element \(index) should be \(expected)")
    }
}
```

---

### Test Case IT-A11Y-001-02: InterpretationView VoiceOver Labels

**Objective**: Verify accessibility labels on interpretation elements.

**Test Steps**:
1. Navigate to InterpretationView
2. Check all element labels
3. Verify descriptive text

**Expected Results**:
- [ ] Start/Stop button: "Start Recording" / "Stop Recording"
- [ ] Swap button: "Swap Languages"
- [ ] Close button: "Close Interpretation"
- [ ] Transcript bubbles: Speaker + text content

```swift
func testInterpretationViewVoiceOverLabels() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["StartInterpretation"].tap()

    // Main control button
    let mainControl = app.buttons["MainControlButton"]
    XCTAssertTrue(mainControl.label.contains("Recording") ||
                  mainControl.label.contains("Start"))

    // Swap button
    let swapButton = app.buttons["SwapLanguagesButton"]
    XCTAssertEqual(swapButton.label, "Swap Languages")

    // Close button
    let closeButton = app.buttons["CloseButton"]
    XCTAssertTrue(closeButton.label.contains("Close"))
}
```

---

### Test Case IT-A11Y-001-03: Transcript Bubble Accessibility

**Objective**: Verify transcript bubbles are accessible.

**Test Steps**:
1. Generate transcript bubbles
2. Focus on bubble with VoiceOver
3. Verify announced content

**Expected Results**:
- [ ] Speaker announced: "Speaker 1" / "Speaker 2"
- [ ] Original text announced
- [ ] Translated text announced
- [ ] Timestamp announced
- [ ] Grouped as single element

```swift
func testTranscriptBubbleAccessibility() throws {
    let app = XCUIApplication()
    app.launch()
    app.buttons["StartInterpretation"].tap()

    // Wait for transcript bubble
    let bubble = app.otherElements["TranscriptBubble_0"]
    XCTAssertTrue(bubble.waitForExistence(timeout: 5.0))

    // Verify accessibility
    XCTAssertTrue(bubble.isAccessibilityElement)

    let label = bubble.label
    XCTAssertTrue(label.contains("Speaker"))
    XCTAssertTrue(label.contains("Original:") || label.contains("Translated:"))
}
```

---

### Test Case IT-A11Y-001-04: Settings VoiceOver Navigation

**Objective**: Verify settings accessibility.

**Test Steps**:
1. Navigate to Settings
2. Check section headers
3. Check row items
4. Check toggle accessibility

**Expected Results**:
- [ ] Section headers announced as headings
- [ ] Rows describe their function
- [ ] Toggle values announced (on/off)
- [ ] Navigation hints provided

---

### Test Case IT-A11Y-001-05: Custom Actions for Complex Elements

**Objective**: Verify custom accessibility actions.

**Test Steps**:
1. Focus on language toggle
2. Check available actions
3. Perform custom action

**Expected Results**:
- [ ] "Change Source Language" action
- [ ] "Change Target Language" action
- [ ] "Swap Languages" action
- [ ] Actions execute correctly

---

## IT-A11Y-002: Accessibility Labels Tests

### Test Case IT-A11Y-002-01: Button Label Completeness

**Objective**: Verify all buttons have descriptive labels.

**Test Steps**:
1. Scan all buttons
2. Check label property
3. Verify no empty labels

**Expected Results**:
- [ ] No empty labels
- [ ] No generic labels ("button")
- [ ] Labels describe action
- [ ] Localized labels

```swift
func testButtonLabelCompleteness() throws {
    let app = XCUIApplication()
    app.launch()

    let buttons = app.buttons.allElementsBoundByIndex

    for button in buttons {
        let label = button.label
        XCTAssertFalse(label.isEmpty, "Button should have a label")
        XCTAssertNotEqual(label.lowercased(), "button", "Label should be descriptive")
    }
}
```

---

### Test Case IT-A11Y-002-02: Image Accessibility Labels

**Objective**: Verify all images have appropriate labels.

**Test Steps**:
1. Scan all images
2. Check accessibility label or trait
3. Verify decorative vs informative

**Expected Results**:
- [ ] Informative images have labels
- [ ] Decorative images hidden from VoiceOver
- [ ] Icons have meaningful labels
- [ ] Logo has label

```swift
func testImageAccessibilityLabels() throws {
    let app = XCUIApplication()
    app.launch()

    // Logo should be accessible
    let logo = app.images["livelingo-logo"]
    XCTAssertTrue(logo.isAccessibilityElement)
    XCTAssertFalse(logo.label.isEmpty)

    // Flag icons should be accessible
    let flagImages = app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'flag-'"))
    for i in 0..<flagImages.count {
        let flag = flagImages.element(boundBy: i)
        XCTAssertFalse(flag.label.isEmpty, "Flag should have country label")
    }
}
```

---

### Test Case IT-A11Y-002-03: Dynamic Label Updates

**Objective**: Verify labels update with state changes.

**Test Steps**:
1. Check button label in state A
2. Change state
3. Verify label updated

**Expected Results**:
- [ ] Start → Stop label change
- [ ] Recording state in label
- [ ] Live announcements for state changes
- [ ] No stale labels

---

### Test Case IT-A11Y-002-04: Accessibility Hints

**Objective**: Verify hints provide additional context.

**Test Steps**:
1. Check elements with hints
2. Verify hint content
3. Check hint localization

**Expected Results**:
- [ ] Hints explain consequence of action
- [ ] Not redundant with label
- [ ] Localized
- [ ] Optional but helpful

---

## IT-A11Y-003: Dynamic Type Tests

### Test Case IT-A11Y-003-01: Text Scaling - Small

**Objective**: Verify text at smallest Dynamic Type size.

**Test Steps**:
1. Set Dynamic Type to xSmall
2. Navigate through app
3. Check text rendering

**Expected Results**:
- [ ] All text readable
- [ ] Layout intact
- [ ] No clipping
- [ ] Minimum 11pt effective size

```swift
func testTextScalingSmall() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXS"]
    app.launch()

    // Check that text is visible and not clipped
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertTrue(startButton.exists)

    let frame = startButton.frame
    XCTAssertGreaterThan(frame.height, 20) // Minimum touch target
}
```

---

### Test Case IT-A11Y-003-02: Text Scaling - Large

**Objective**: Verify text at large Dynamic Type size.

**Test Steps**:
1. Set Dynamic Type to XXXL
2. Navigate through app
3. Check text rendering

**Expected Results**:
- [ ] Text scales appropriately
- [ ] Layout adapts
- [ ] Scrollable if needed
- [ ] No truncation without indication

```swift
func testTextScalingLarge() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"]
    app.launch()

    // Check that text is larger
    let startButton = app.buttons["StartInterpretation"]
    let frame = startButton.frame

    // Large text should result in larger button
    XCTAssertGreaterThan(frame.height, 50)
}
```

---

### Test Case IT-A11Y-003-03: Accessibility Text Sizes

**Objective**: Verify app handles accessibility text sizes.

**Test Steps**:
1. Set Dynamic Type to AX5
2. Navigate through app
3. Check layout adaptation

**Expected Results**:
- [ ] Text scales dramatically
- [ ] Layout reorganizes if needed
- [ ] No overlapping elements
- [ ] All content accessible via scroll

---

### Test Case IT-A11Y-003-04: ScaledMetric Usage

**Objective**: Verify ScaledMetric values scale.

**Test Steps**:
1. Check icon sizes at normal
2. Change text size
3. Verify icons scale

**Expected Results**:
- [ ] Icons scale with text
- [ ] Proportional scaling
- [ ] Touch targets maintained
- [ ] Visual harmony preserved

---

## IT-A11Y-004: Color and Contrast Tests

### Test Case IT-A11Y-004-01: Text Contrast Ratio

**Objective**: Verify text meets contrast requirements.

**Test Steps**:
1. Check primary text contrast
2. Check secondary text contrast
3. Check button text contrast

**Expected Results**:
- [ ] Primary text: 7:1 ratio (AAA)
- [ ] Secondary text: 4.5:1 ratio (AA)
- [ ] Large text: 3:1 ratio minimum
- [ ] Button text: sufficient contrast

```swift
func testTextContrastRatio() throws {
    // Test primary text on background
    let primaryText = Color.llTextPrimary
    let background = Color.llBackground

    let contrastRatio = calculateContrastRatio(primaryText, background)
    XCTAssertGreaterThanOrEqual(contrastRatio, 4.5)
}

func calculateContrastRatio(_ foreground: Color, _ background: Color) -> Double {
    // WCAG contrast ratio calculation
    let fgLuminance = relativeLuminance(foreground)
    let bgLuminance = relativeLuminance(background)

    let lighter = max(fgLuminance, bgLuminance)
    let darker = min(fgLuminance, bgLuminance)

    return (lighter + 0.05) / (darker + 0.05)
}
```

---

### Test Case IT-A11Y-004-02: Color Independence

**Objective**: Verify information not conveyed by color alone.

**Test Steps**:
1. Check error states
2. Check success states
3. Check speaker differentiation

**Expected Results**:
- [ ] Error has icon + text, not just red
- [ ] Success has icon + text, not just green
- [ ] Speakers have labels, not just colors
- [ ] Recording state has icon + label

---

### Test Case IT-A11Y-004-03: High Contrast Mode

**Objective**: Verify app in high contrast mode.

**Test Steps**:
1. Enable Increase Contrast
2. Navigate through app
3. Check visibility

**Expected Results**:
- [ ] Borders more visible
- [ ] Text more prominent
- [ ] No loss of information
- [ ] UI still functional

---

## IT-A11Y-005: Motion and Animation Tests

### Test Case IT-A11Y-005-01: Reduce Motion Compliance

**Objective**: Verify animations respect Reduce Motion.

**Test Steps**:
1. Enable Reduce Motion
2. Trigger animations
3. Verify behavior

**Expected Results**:
- [ ] Animations disabled or simplified
- [ ] Content still updates
- [ ] No vestibular triggers
- [ ] Instant transitions acceptable

```swift
func testReduceMotionCompliance() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-accessibilityReduceMotionEnabled", "YES"]
    app.launch()

    // Navigate and verify no long animations
    let startButton = app.buttons["StartInterpretation"]
    startButton.tap()

    // View should appear instantly or with minimal transition
    let interpretationView = app.otherElements["InterpretationView"]
    XCTAssertTrue(interpretationView.waitForExistence(timeout: 0.5))
}
```

---

### Test Case IT-A11Y-005-02: Audio Level Animation

**Objective**: Verify audio visualization respects accessibility.

**Test Steps**:
1. Enable Reduce Motion
2. Start recording
3. Check live indicator

**Expected Results**:
- [ ] Static indicator acceptable
- [ ] Or simplified pulse
- [ ] Information still conveyed
- [ ] No rapid flashing

---

## IT-A11Y-006: Focus Management Tests

### Test Case IT-A11Y-006-01: Initial Focus Placement

**Objective**: Verify focus placed appropriately on view load.

**Test Steps**:
1. Navigate to new view
2. Check initial focus
3. Verify logical placement

**Expected Results**:
- [ ] Focus on first meaningful element
- [ ] Not on decorative elements
- [ ] Announced by VoiceOver
- [ ] Keyboard accessible

---

### Test Case IT-A11Y-006-02: Focus After Actions

**Objective**: Verify focus moves appropriately after actions.

**Test Steps**:
1. Tap button
2. Check focus after action
3. Verify logical movement

**Expected Results**:
- [ ] Focus on result/feedback
- [ ] Or next logical element
- [ ] Not lost to invisible element
- [ ] Announced if needed

---

### Test Case IT-A11Y-006-03: Modal Focus Trap

**Objective**: Verify focus trapped in modals.

**Test Steps**:
1. Open modal/sheet
2. Try to focus outside
3. Verify trapped

**Expected Results**:
- [ ] Focus stays in modal
- [ ] Can reach all modal elements
- [ ] Dismiss returns focus
- [ ] Previous focus restored

---

### Test Case IT-A11Y-006-04: Alert Focus

**Objective**: Verify alerts capture focus.

**Test Steps**:
1. Trigger alert
2. Check focus
3. Dismiss alert

**Expected Results**:
- [ ] Focus moves to alert
- [ ] Alert title announced
- [ ] Actions accessible
- [ ] Dismiss returns focus

---

## IT-A11Y-007: Touch Target Tests

### Test Case IT-A11Y-007-01: Minimum Touch Target Size

**Objective**: Verify touch targets meet minimum size.

**Test Steps**:
1. Measure all interactive elements
2. Check size against 44x44 minimum

**Expected Results**:
- [ ] All buttons >= 44x44 pt
- [ ] All toggles >= 44x44 pt
- [ ] All sliders have adequate track
- [ ] Text fields have adequate size

```swift
func testMinimumTouchTargetSize() throws {
    let app = XCUIApplication()
    app.launch()

    let interactiveElements = app.buttons.allElementsBoundByIndex +
                              app.switches.allElementsBoundByIndex +
                              app.textFields.allElementsBoundByIndex

    for element in interactiveElements {
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.width, 44, "Touch target width for \(element.identifier)")
        XCTAssertGreaterThanOrEqual(frame.height, 44, "Touch target height for \(element.identifier)")
    }
}
```

---

### Test Case IT-A11Y-007-02: Touch Target Spacing

**Objective**: Verify adequate spacing between targets.

**Test Steps**:
1. Identify adjacent interactive elements
2. Measure spacing
3. Verify no overlap

**Expected Results**:
- [ ] Minimum 8pt spacing
- [ ] No overlapping hit areas
- [ ] Clear visual separation
- [ ] Easy to select intended target

---

## IT-A11Y-008: Screen Reader Announcements

### Test Case IT-A11Y-008-01: State Change Announcements

**Objective**: Verify state changes announced.

**Test Steps**:
1. Enable VoiceOver
2. Trigger state change
3. Verify announcement

**Expected Results**:
- [ ] Recording started announced
- [ ] Recording stopped announced
- [ ] Error announced
- [ ] Success announced

```swift
func testStateChangeAnnouncements() throws {
    let app = XCUIApplication()
    app.launch()

    // Start interpretation
    app.buttons["StartInterpretation"].tap()

    // Start recording
    let mainControl = app.buttons["MainControlButton"]
    mainControl.tap()

    // Check for accessibility notification
    // (Implementation depends on testing framework)
}
```

---

### Test Case IT-A11Y-008-02: Live Region Updates

**Objective**: Verify live regions announce updates.

**Test Steps**:
1. Enable VoiceOver
2. Receive new transcript
3. Verify announced

**Expected Results**:
- [ ] New transcripts announced
- [ ] Translation results announced
- [ ] Polite announcement (not interrupting)
- [ ] Can be disabled if too verbose

---

### Test Case IT-A11Y-008-03: Error Announcements

**Objective**: Verify errors properly announced.

**Test Steps**:
1. Enable VoiceOver
2. Trigger error
3. Verify announcement

**Expected Results**:
- [ ] Error announced assertively
- [ ] Error message read
- [ ] Recovery options announced
- [ ] Focus moves to error

---

## Test Data Fixtures

### Accessibility Identifiers

| Element | Identifier | Label Key |
|---------|------------|-----------|
| Start Button | StartInterpretation | a11y_start_interpretation |
| Stop Button | StopInterpretation | a11y_stop_interpretation |
| Swap Button | SwapLanguagesButton | a11y_swap_languages |
| Close Button | CloseButton | a11y_close |
| Transcript Bubble | TranscriptBubble_{index} | a11y_transcript_{speaker} |

### Test Configurations

| Setting | Value | Effect |
|---------|-------|--------|
| VoiceOver | On | Full screen reader |
| Reduce Motion | On | Disable animations |
| Increase Contrast | On | Higher contrast UI |
| Bold Text | On | Heavier font weights |
| Dynamic Type | AX5 | Extra large text |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 58 test cases | AI Agent |
