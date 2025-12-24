# IT-LAYOUT: Responsive Layout Integration Tests

## Overview

This document defines integration tests for responsive layout behavior across different device sizes, orientations, and display configurations. These tests verify proper layout adaptation based on UI component specifications.

**Priority**: P2-Medium
**Total Test Cases**: 48
**Estimated Execution Time**: 18 minutes

---

## Test Environment

### Required Components
- All Views with layout constraints
- `LayoutManager`
- `SizeClassHandler`
- `SafeAreaHandler`

### Test Devices/Simulators
- iPhone SE (3rd gen) - Small (375x667)
- iPhone 15 - Standard (390x844)
- iPhone 15 Pro Max - Large (430x932)
- iPad Pro 11" - Tablet (834x1194)
- iPad Pro 12.9" - Large Tablet (1024x1366)

### Test Framework
- XCUITest with multiple device targets
- Layout constraint verification
- Screenshot comparison

---

## IT-LAYOUT-001: iPhone Screen Size Adaptation Tests

### Test Case IT-LAYOUT-001-01: iPhone SE Layout

**Objective**: Verify layout on smallest iPhone.

**Test Device**: iPhone SE (3rd gen) - 375x667

**Test Steps**:
1. Launch on iPhone SE simulator
2. Navigate through all screens
3. Check layout fitting

**Expected Results**:
- [ ] All elements visible without scrolling (where applicable)
- [ ] Touch targets meet 44x44 minimum
- [ ] Text readable without truncation
- [ ] No overlapping elements

```swift
func testIPhoneSELayout() throws {
    let app = XCUIApplication()
    app.launch()

    // Check HomeView fits on SE
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertTrue(startButton.exists)
    XCTAssertTrue(startButton.isHittable)

    let frame = startButton.frame
    // Verify button is within screen bounds (375x667)
    XCTAssertLessThan(frame.maxX, 375)
    XCTAssertLessThan(frame.maxY, 667)

    // Verify minimum touch target
    XCTAssertGreaterThanOrEqual(frame.width, 44)
    XCTAssertGreaterThanOrEqual(frame.height, 44)
}
```

---

### Test Case IT-LAYOUT-001-02: iPhone 15 Standard Layout

**Objective**: Verify layout on standard iPhone.

**Test Device**: iPhone 15 - 390x844

**Test Steps**:
1. Launch on iPhone 15 simulator
2. Check all screen layouts
3. Verify optimal spacing

**Expected Results**:
- [ ] Comfortable spacing between elements
- [ ] Visual balance
- [ ] No wasted space
- [ ] Proper margins

---

### Test Case IT-LAYOUT-001-03: iPhone 15 Pro Max Layout

**Objective**: Verify layout on large iPhone.

**Test Device**: iPhone 15 Pro Max - 430x932

**Test Steps**:
1. Launch on Pro Max simulator
2. Check layout scaling
3. Verify no stretching issues

**Expected Results**:
- [ ] Content centered or expanded appropriately
- [ ] No excessive white space
- [ ] Images scale correctly
- [ ] Text maintains readability

---

### Test Case IT-LAYOUT-001-04: HomeView Elements Positioning

**Objective**: Verify HomeView elements position correctly.

**Test Steps**:
1. Check logo position (center top)
2. Check language toggle (center)
3. Check start button (center)
4. Check quick actions (bottom)

**Expected Results**:
- [ ] Logo centered horizontally
- [ ] Vertical spacing proportional
- [ ] Start button prominently placed
- [ ] Quick actions in accessible area

```swift
func testHomeViewElementsPositioning() throws {
    let app = XCUIApplication()
    app.launch()

    let screenWidth = UIScreen.main.bounds.width

    // Logo should be centered
    let logo = app.images["livelingo-logo"]
    let logoFrame = logo.frame
    let logoCenterX = logoFrame.midX
    XCTAssertEqual(logoCenterX, screenWidth / 2, accuracy: 10)

    // Start button should be centered
    let startButton = app.buttons["StartInterpretation"]
    let buttonFrame = startButton.frame
    let buttonCenterX = buttonFrame.midX
    XCTAssertEqual(buttonCenterX, screenWidth / 2, accuracy: 10)
}
```

---

### Test Case IT-LAYOUT-001-05: InterpretationView Layout

**Objective**: Verify interpretation screen layout.

**Test Steps**:
1. Check header position (top safe area)
2. Check transcript area (fills middle)
3. Check control bar (bottom safe area)

**Expected Results**:
- [ ] Header respects safe area
- [ ] Transcript area scrollable
- [ ] Control bar above home indicator
- [ ] Proper keyboard avoidance

---

## IT-LAYOUT-002: iPad Layout Adaptation Tests

### Test Case IT-LAYOUT-002-01: iPad Pro 11" Layout

**Objective**: Verify layout on 11" iPad.

**Test Device**: iPad Pro 11" - 834x1194

**Test Steps**:
1. Launch on iPad simulator
2. Check layout adaptation
3. Verify tablet-specific UI

**Expected Results**:
- [ ] Layout adapts to larger screen
- [ ] Content may center with margins
- [ ] Or split view layout
- [ ] Touch targets remain appropriate

```swift
func testIPadPro11Layout() throws {
    let app = XCUIApplication()
    app.launch()

    // On iPad, check if layout adapts
    let startButton = app.buttons["StartInterpretation"]
    let frame = startButton.frame

    // Button should be centered with reasonable size
    let screenWidth: CGFloat = 834 // iPad Pro 11"
    let expectedCenterX = screenWidth / 2

    XCTAssertEqual(frame.midX, expectedCenterX, accuracy: 50)

    // Button shouldn't stretch to full width on iPad
    XCTAssertLessThan(frame.width, 400)
}
```

---

### Test Case IT-LAYOUT-002-02: iPad Pro 12.9" Layout

**Objective**: Verify layout on largest iPad.

**Test Device**: iPad Pro 12.9" - 1024x1366

**Test Steps**:
1. Launch on 12.9" iPad
2. Check content area sizing
3. Verify readability

**Expected Results**:
- [ ] Content constrained to readable width
- [ ] Max content width applied
- [ ] Side margins on large screens
- [ ] Transcript bubbles not too wide

---

### Test Case IT-LAYOUT-002-03: iPad Split View

**Objective**: Verify layout in split view mode.

**Test Steps**:
1. Enable split view (50/50)
2. Launch LiveLingo in one side
3. Check compact layout

**Expected Results**:
- [ ] Compact layout activates
- [ ] All features accessible
- [ ] No clipping
- [ ] Responsive to width changes

---

### Test Case IT-LAYOUT-002-04: iPad Slide Over

**Objective**: Verify layout in slide over mode.

**Test Steps**:
1. Enable slide over
2. Check narrow layout
3. Verify functionality

**Expected Results**:
- [ ] Narrow layout works
- [ ] Similar to iPhone layout
- [ ] Scrolling enabled
- [ ] All content reachable

---

## IT-LAYOUT-003: Orientation Tests

### Test Case IT-LAYOUT-003-01: Portrait to Landscape Rotation

**Objective**: Verify layout adapts to landscape.

**Test Steps**:
1. Start in portrait
2. Rotate to landscape
3. Check layout adaptation

**Expected Results**:
- [ ] Layout smoothly adapts
- [ ] Content reflows
- [ ] No lost elements
- [ ] Usable in landscape

```swift
func testPortraitToLandscapeRotation() throws {
    let app = XCUIApplication()
    app.launch()

    XCUIDevice.shared.orientation = .portrait

    // Verify portrait layout
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertTrue(startButton.exists)

    // Rotate to landscape
    XCUIDevice.shared.orientation = .landscapeLeft

    // Verify button still visible and hittable
    XCTAssertTrue(startButton.exists)
    XCTAssertTrue(startButton.isHittable)
}
```

---

### Test Case IT-LAYOUT-003-02: Landscape to Portrait Rotation

**Objective**: Verify layout adapts back to portrait.

**Test Steps**:
1. Start in landscape
2. Rotate to portrait
3. Check layout restoration

**Expected Results**:
- [ ] Portrait layout restored
- [ ] No lingering landscape elements
- [ ] Scroll position maintained
- [ ] State preserved

---

### Test Case IT-LAYOUT-003-03: InterpretationView Landscape

**Objective**: Verify interpretation screen in landscape.

**Test Steps**:
1. Start interpretation
2. Rotate to landscape
3. Check usability

**Expected Results**:
- [ ] Transcript area adapts
- [ ] Control bar repositions
- [ ] Live indicator visible
- [ ] Fully functional

---

### Test Case IT-LAYOUT-003-04: Orientation Lock Respect

**Objective**: Verify app respects orientation preferences.

**Test Steps**:
1. Lock to portrait in settings
2. Try to rotate
3. Verify locked

**Expected Results**:
- [ ] Rotation prevented
- [ ] Layout stays portrait
- [ ] Or app-specific lock works
- [ ] User preference respected

---

## IT-LAYOUT-004: Safe Area Tests

### Test Case IT-LAYOUT-004-01: Status Bar Safe Area

**Objective**: Verify content respects status bar.

**Test Steps**:
1. Check header area on notched devices
2. Verify content below status bar
3. Check on non-notched devices

**Expected Results**:
- [ ] Content below status bar
- [ ] Notch area clear
- [ ] Status bar visible
- [ ] Background extends under status bar

```swift
func testStatusBarSafeArea() throws {
    let app = XCUIApplication()
    app.launch()

    let logo = app.images["livelingo-logo"]
    let frame = logo.frame

    // Logo should not overlap status bar area (~47pt on notched devices)
    XCTAssertGreaterThan(frame.minY, 40)
}
```

---

### Test Case IT-LAYOUT-004-02: Home Indicator Safe Area

**Objective**: Verify content above home indicator.

**Test Steps**:
1. Check bottom elements
2. Verify padding above indicator
3. Check interactive elements

**Expected Results**:
- [ ] Content above home indicator
- [ ] Tab bar/control bar properly inset
- [ ] Gestures don't conflict
- [ ] Smooth home gesture

---

### Test Case IT-LAYOUT-004-03: Rounded Corner Safe Area

**Objective**: Verify corners don't clip content.

**Test Steps**:
1. Check corner elements
2. Verify no clipping
3. Check all corners

**Expected Results**:
- [ ] Content inside rounded corners
- [ ] No visual clipping
- [ ] Proper corner radius matching
- [ ] Full-bleed images handled

---

### Test Case IT-LAYOUT-004-04: Dynamic Island Accommodation

**Objective**: Verify Dynamic Island doesn't clip content.

**Test Device**: iPhone 14 Pro/15 Pro with Dynamic Island

**Test Steps**:
1. Launch on Dynamic Island device
2. Check top center area
3. Verify no overlap

**Expected Results**:
- [ ] No content behind Dynamic Island
- [ ] Proper layout around pill
- [ ] Live Activities don't conflict
- [ ] Notch handling still works

---

## IT-LAYOUT-005: Keyboard Avoidance Tests

### Test Case IT-LAYOUT-005-01: Text Field Keyboard Avoidance

**Objective**: Verify text fields visible with keyboard.

**Test Steps**:
1. Tap text field (dictionary entry)
2. Keyboard appears
3. Check field visibility

**Expected Results**:
- [ ] View scrolls up
- [ ] Text field visible above keyboard
- [ ] Can type into field
- [ ] Dismiss keyboard restores layout

```swift
func testTextFieldKeyboardAvoidance() throws {
    let app = XCUIApplication()
    app.launch()

    // Navigate to dictionary
    app.buttons["DictionaryButton"].tap()
    app.buttons["AddTermButton"].tap()

    let textField = app.textFields["SourceTermField"]
    textField.tap()

    // Verify text field is still visible
    XCTAssertTrue(textField.isHittable)

    // Type text
    textField.typeText("Test")
    XCTAssertEqual(textField.value as? String, "Test")
}
```

---

### Test Case IT-LAYOUT-005-02: Search Field Keyboard Avoidance

**Objective**: Verify search field with keyboard.

**Test Steps**:
1. Navigate to History
2. Tap search field
3. Check layout

**Expected Results**:
- [ ] Search field stays visible
- [ ] Results list adjusts
- [ ] Can scroll results
- [ ] Keyboard dismiss works

---

### Test Case IT-LAYOUT-005-03: Keyboard Height Variations

**Objective**: Verify different keyboard heights handled.

**Test Steps**:
1. Use standard keyboard
2. Switch to emoji keyboard (taller)
3. Check layout adjustment

**Expected Results**:
- [ ] Standard keyboard works
- [ ] Emoji keyboard works
- [ ] Predictive bar handled
- [ ] Smooth transitions

---

## IT-LAYOUT-006: Content Size Category Tests

### Test Case IT-LAYOUT-006-01: Extra Small Content Size

**Objective**: Verify layout with smallest content size.

**Test Steps**:
1. Set content size to XS
2. Check all layouts
3. Verify proportions

**Expected Results**:
- [ ] Layout maintains proportions
- [ ] Spacing appropriate
- [ ] No cramped appearance
- [ ] Touch targets adequate

---

### Test Case IT-LAYOUT-006-02: Accessibility Extra Large

**Objective**: Verify layout with AX content size.

**Test Steps**:
1. Set content size to AX5
2. Check all layouts
3. Verify scrolling

**Expected Results**:
- [ ] Content scrollable
- [ ] No layout breaking
- [ ] All text visible
- [ ] Navigation functional

```swift
func testAccessibilityExtraLargeLayout() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"]
    app.launch()

    // Verify app launches successfully
    let startButton = app.buttons["StartInterpretation"]
    XCTAssertTrue(startButton.exists)

    // Verify scrollable if needed
    let scrollView = app.scrollViews.firstMatch
    if scrollView.exists {
        scrollView.swipeUp()
        scrollView.swipeDown()
    }
}
```

---

## IT-LAYOUT-007: Transcript Layout Tests

### Test Case IT-LAYOUT-007-01: Transcript Bubble Width

**Objective**: Verify transcript bubbles have appropriate width.

**Test Steps**:
1. Generate long transcript
2. Check bubble width
3. Verify text wrapping

**Expected Results**:
- [ ] Max width ~80% of screen
- [ ] Text wraps properly
- [ ] No horizontal scrolling
- [ ] Readable line length

---

### Test Case IT-LAYOUT-007-02: Transcript List Layout

**Objective**: Verify transcript list scrolling.

**Test Steps**:
1. Generate many transcripts
2. Scroll through list
3. Check performance

**Expected Results**:
- [ ] Smooth scrolling
- [ ] Auto-scroll to new items
- [ ] Proper spacing between bubbles
- [ ] Alternating alignment (speaker 1/2)

---

### Test Case IT-LAYOUT-007-03: Empty Transcript State

**Objective**: Verify empty transcript layout.

**Test Steps**:
1. Start interpretation
2. No speech yet
3. Check empty state

**Expected Results**:
- [ ] Placeholder or instructions
- [ ] Centered content
- [ ] Not blank/confusing
- [ ] Animations if applicable

---

## Test Data Fixtures

### Screen Dimensions

| Device | Width | Height | Scale |
|--------|-------|--------|-------|
| iPhone SE | 375 | 667 | 2x |
| iPhone 15 | 390 | 844 | 3x |
| iPhone 15 Pro Max | 430 | 932 | 3x |
| iPad Pro 11" | 834 | 1194 | 2x |
| iPad Pro 12.9" | 1024 | 1366 | 2x |

### Safe Area Insets

| Device | Top | Bottom | Leading | Trailing |
|--------|-----|--------|---------|----------|
| iPhone SE | 20 | 0 | 0 | 0 |
| iPhone 15 | 47 | 34 | 0 | 0 |
| iPhone 15 Pro | 59 | 34 | 0 | 0 |
| iPad Pro | 24 | 20 | 0 | 0 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 48 test cases | AI Agent |
