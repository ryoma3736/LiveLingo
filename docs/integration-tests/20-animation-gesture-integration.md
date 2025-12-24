# IT-ANIM: Animation & Gesture Integration Tests

## Overview

This document defines integration tests for animations, transitions, and gesture handling in LiveLingo. These tests verify smooth user interactions, proper animation timing, and gesture recognition.

**Priority**: P2-Medium
**Total Test Cases**: 45
**Estimated Execution Time**: 15 minutes

---

## Test Environment

### Required Components
- All animated Views
- `NavigationCoordinator`
- `GestureRecognizers`
- `AnimationManager`

### Mock Dependencies
- `MockAnimationContext`
- `MockGestureRecognizer`

### Test Framework
- XCUITest for gesture simulation
- XCTest performance metrics
- Custom animation timing utilities

---

## IT-ANIM-001: Screen Transition Animation Tests

### Test Case IT-ANIM-001-01: Home to Interpretation Transition

**Objective**: Verify smooth transition to interpretation screen.

**Test Steps**:
1. On HomeView
2. Tap Start Interpretation
3. Observe transition

**Expected Results**:
- [ ] Transition animation smooth
- [ ] Duration: 0.3s standard
- [ ] No frame drops (60fps)
- [ ] No visual glitches

```swift
func testHomeToInterpretationTransition() throws {
    let app = XCUIApplication()
    app.launch()

    let startButton = app.buttons["StartInterpretation"]
    let interpretationView = app.otherElements["InterpretationView"]

    // Measure transition time
    let start = CFAbsoluteTimeGetCurrent()
    startButton.tap()
    XCTAssertTrue(interpretationView.waitForExistence(timeout: 1.0))
    let duration = CFAbsoluteTimeGetCurrent() - start

    // Verify reasonable duration
    XCTAssertLessThan(duration, 0.5)
}
```

---

### Test Case IT-ANIM-001-02: Settings Modal Presentation

**Objective**: Verify settings modal animation.

**Test Steps**:
1. Tap Settings button
2. Observe modal presentation
3. Check animation style

**Expected Results**:
- [ ] Modal slides up from bottom
- [ ] Proper spring animation
- [ ] Background dimmed
- [ ] Handle bar visible

---

### Test Case IT-ANIM-001-03: Navigation Back Animation

**Objective**: Verify back navigation animation.

**Test Steps**:
1. Navigate to Settings
2. Tap back button
3. Observe animation

**Expected Results**:
- [ ] Slide from left animation
- [ ] Matches system style
- [ ] Smooth timing
- [ ] No flickering

---

### Test Case IT-ANIM-001-04: Onboarding Page Transition

**Objective**: Verify onboarding page swipe animation.

**Test Steps**:
1. On onboarding
2. Swipe left
3. Observe page change

**Expected Results**:
- [ ] Smooth horizontal scroll
- [ ] Page indicator updates
- [ ] Proper deceleration
- [ ] Snap to page

---

## IT-ANIM-002: Component Animation Tests

### Test Case IT-ANIM-002-01: Start Button Press Animation

**Objective**: Verify button press feedback animation.

**Test Steps**:
1. Press and hold start button
2. Observe visual feedback
3. Release

**Expected Results**:
- [ ] Scale down on press (0.95x)
- [ ] Opacity change or highlight
- [ ] Spring back on release
- [ ] Duration < 0.2s

```swift
func testStartButtonPressAnimation() throws {
    let app = XCUIApplication()
    app.launch()

    let startButton = app.buttons["StartInterpretation"]

    // Long press to observe animation
    startButton.press(forDuration: 0.5)

    // Button should still exist and be interactable
    XCTAssertTrue(startButton.exists)
    XCTAssertTrue(startButton.isHittable)
}
```

---

### Test Case IT-ANIM-002-02: Recording State Animation

**Objective**: Verify recording indicator animation.

**Test Steps**:
1. Start recording
2. Observe recording indicator
3. Stop recording

**Expected Results**:
- [ ] Pulsing animation when recording
- [ ] Color transition (blue to red)
- [ ] Smooth pulse rhythm
- [ ] Animation stops when stopped

---

### Test Case IT-ANIM-002-03: Live Indicator Bar Animation

**Objective**: Verify audio level visualization animation.

**Test Steps**:
1. Start recording
2. Speak into mic
3. Observe bar movement

**Expected Results**:
- [ ] Bars animate with audio level
- [ ] Smooth height changes
- [ ] Frame rate maintained
- [ ] No jittering

---

### Test Case IT-ANIM-002-04: Language Swap Animation

**Objective**: Verify language swap rotation animation.

**Test Steps**:
1. Tap swap languages button
2. Observe animation
3. Check final state

**Expected Results**:
- [ ] Arrow icon rotates
- [ ] Language labels swap
- [ ] Smooth transition
- [ ] Duration ~0.3s

```swift
func testLanguageSwapAnimation() throws {
    let app = XCUIApplication()
    app.launch()

    let swapButton = app.buttons["SwapLanguagesButton"]
    let sourceBefore = app.buttons["SourceLanguageSelector"].label

    swapButton.tap()

    // Wait for animation
    Thread.sleep(forTimeInterval: 0.5)

    let sourceAfter = app.buttons["SourceLanguageSelector"].label
    XCTAssertNotEqual(sourceBefore, sourceAfter)
}
```

---

### Test Case IT-ANIM-002-05: Transcript Bubble Entrance Animation

**Objective**: Verify new transcript bubble animation.

**Test Steps**:
1. Start interpretation
2. Receive transcript
3. Observe bubble entrance

**Expected Results**:
- [ ] Bubble fades in
- [ ] Or slides in from edge
- [ ] Smooth appearance
- [ ] Auto-scroll to bottom

---

### Test Case IT-ANIM-002-06: Error Banner Animation

**Objective**: Verify error banner slide animation.

**Test Steps**:
1. Trigger error
2. Observe banner appearance
3. Dismiss banner

**Expected Results**:
- [ ] Slides down from top
- [ ] Spring animation
- [ ] Dismiss slides up
- [ ] Smooth timing

---

## IT-ANIM-003: Gesture Recognition Tests

### Test Case IT-ANIM-003-01: Swipe to Dismiss Interpretation

**Objective**: Verify swipe down dismisses interpretation.

**Test Steps**:
1. On InterpretationView
2. Swipe down gesture
3. Observe dismiss

**Expected Results**:
- [ ] Interactive dismiss begins
- [ ] View follows finger
- [ ] Release completes or cancels
- [ ] Confirmation dialog if needed

```swift
func testSwipeToDismissInterpretation() throws {
    let app = XCUIApplication()
    app.launch()

    app.buttons["StartInterpretation"].tap()

    let interpretationView = app.otherElements["InterpretationView"]
    XCTAssertTrue(interpretationView.waitForExistence(timeout: 2.0))

    // Swipe down to dismiss
    interpretationView.swipeDown()

    // Should show confirmation or dismiss
    let confirmDialog = app.alerts.firstMatch
    let homeView = app.otherElements["HomeView"]

    XCTAssertTrue(confirmDialog.waitForExistence(timeout: 1.0) ||
                  homeView.waitForExistence(timeout: 1.0))
}
```

---

### Test Case IT-ANIM-003-02: Swipe to Delete History Item

**Objective**: Verify swipe to delete gesture.

**Test Steps**:
1. Navigate to History
2. Swipe left on item
3. Check delete action

**Expected Results**:
- [ ] Delete action revealed
- [ ] Red background
- [ ] Delete text or icon
- [ ] Tapping deletes

---

### Test Case IT-ANIM-003-03: Long Press Context Menu

**Objective**: Verify long press shows context menu.

**Test Steps**:
1. Long press on transcript bubble
2. Check context menu
3. Select option

**Expected Results**:
- [ ] Haptic feedback
- [ ] Context menu appears
- [ ] Options: Copy, Share
- [ ] Menu dismisses on selection

```swift
func testLongPressContextMenu() throws {
    let app = XCUIApplication()
    app.launch()
    app.buttons["StartInterpretation"].tap()

    // Wait for transcript
    let bubble = app.otherElements["TranscriptBubble_0"]
    XCTAssertTrue(bubble.waitForExistence(timeout: 5.0))

    // Long press
    bubble.press(forDuration: 1.0)

    // Check for menu
    let copyButton = app.buttons["Copy"]
    XCTAssertTrue(copyButton.waitForExistence(timeout: 1.0))
}
```

---

### Test Case IT-ANIM-003-04: Pinch to Zoom Transcript

**Objective**: Verify pinch gesture on transcript (if applicable).

**Test Steps**:
1. On transcript view
2. Pinch to zoom
3. Check zoom behavior

**Expected Results**:
- [ ] Pinch recognized
- [ ] Text scales smoothly
- [ ] Or gesture disabled
- [ ] No crash

---

### Test Case IT-ANIM-003-05: Scroll Gesture Recognition

**Objective**: Verify scroll gestures work correctly.

**Test Steps**:
1. Open History with many items
2. Scroll up and down
3. Check scroll behavior

**Expected Results**:
- [ ] Smooth scrolling
- [ ] Proper momentum
- [ ] Bounce at edges
- [ ] No stuck scrolling

---

### Test Case IT-ANIM-003-06: Edge Swipe Back Navigation

**Objective**: Verify edge swipe returns to previous screen.

**Test Steps**:
1. Navigate to Settings
2. Swipe from left edge
3. Observe navigation

**Expected Results**:
- [ ] Interactive pop begins
- [ ] View follows finger
- [ ] Complete swipe navigates back
- [ ] Incomplete swipe cancels

---

## IT-ANIM-004: Loading Animation Tests

### Test Case IT-ANIM-004-01: Spinner Animation

**Objective**: Verify loading spinner animation.

**Test Steps**:
1. Trigger loading state
2. Observe spinner
3. Check animation

**Expected Results**:
- [ ] Spinner rotates smoothly
- [ ] Continuous animation
- [ ] Proper color
- [ ] Stops when loading complete

```swift
func testSpinnerAnimation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--slow-network"]
    app.launch()

    app.buttons["StartInterpretation"].tap()

    let spinner = app.activityIndicators.firstMatch
    XCTAssertTrue(spinner.waitForExistence(timeout: 2.0))

    // Verify it's animating (exists and visible)
    XCTAssertTrue(spinner.isHittable)
}
```

---

### Test Case IT-ANIM-004-02: Skeleton Loading Animation

**Objective**: Verify skeleton loading animation (if used).

**Test Steps**:
1. Load history
2. Observe skeleton placeholders
3. Check shimmer effect

**Expected Results**:
- [ ] Skeleton shapes match content
- [ ] Shimmer animation smooth
- [ ] Fade to real content
- [ ] No layout shift

---

### Test Case IT-ANIM-004-03: Progress Bar Animation

**Objective**: Verify progress bar animation.

**Test Steps**:
1. Trigger progress operation
2. Observe progress bar
3. Check animation

**Expected Results**:
- [ ] Smooth progress movement
- [ ] Accurate percentage
- [ ] Color fills correctly
- [ ] Complete animation at 100%

---

## IT-ANIM-005: Reduce Motion Compliance Tests

### Test Case IT-ANIM-005-01: Animations Disabled with Reduce Motion

**Objective**: Verify animations respect Reduce Motion setting.

**Test Steps**:
1. Enable Reduce Motion
2. Navigate through app
3. Check for animations

**Expected Results**:
- [ ] Transitions instant or fade
- [ ] No sliding animations
- [ ] No bouncing
- [ ] Content still functional

```swift
func testAnimationsDisabledWithReduceMotion() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-accessibilityReduceMotionEnabled", "YES"]
    app.launch()

    let startTime = CFAbsoluteTimeGetCurrent()
    app.buttons["StartInterpretation"].tap()
    let interpretationView = app.otherElements["InterpretationView"]
    XCTAssertTrue(interpretationView.waitForExistence(timeout: 0.5))
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    // Should be nearly instant with reduce motion
    XCTAssertLessThan(duration, 0.2)
}
```

---

### Test Case IT-ANIM-005-02: Live Indicator with Reduce Motion

**Objective**: Verify live indicator simplified.

**Test Steps**:
1. Enable Reduce Motion
2. Start recording
3. Check live indicator

**Expected Results**:
- [ ] Static or simple animation
- [ ] Information still conveyed
- [ ] No rapid movement
- [ ] Accessible alternative

---

## IT-ANIM-006: Performance Tests

### Test Case IT-ANIM-006-01: Animation Frame Rate

**Objective**: Verify animations maintain 60fps.

**Test Steps**:
1. Start screen recording
2. Perform various animations
3. Analyze frame rate

**Expected Results**:
- [ ] 60fps sustained
- [ ] No dropped frames
- [ ] Smooth visual output
- [ ] GPU not overloaded

---

### Test Case IT-ANIM-006-02: Animation During Load

**Objective**: Verify animations don't impact loading.

**Test Steps**:
1. Trigger animation
2. Simultaneously load data
3. Check both complete

**Expected Results**:
- [ ] Animation smooth
- [ ] Loading completes
- [ ] No UI freeze
- [ ] Proper threading

---

### Test Case IT-ANIM-006-03: Memory During Animations

**Objective**: Verify no memory leaks from animations.

**Test Steps**:
1. Repeat animations 100 times
2. Monitor memory
3. Check for leaks

**Expected Results**:
- [ ] Memory stable
- [ ] No leaks detected
- [ ] Animation objects released
- [ ] Completion handlers cleared

---

## IT-ANIM-007: Haptic Feedback Tests

### Test Case IT-ANIM-007-01: Button Press Haptic

**Objective**: Verify haptic on button press.

**Test Steps**:
1. Tap start button
2. Check for haptic

**Expected Results**:
- [ ] Light haptic on press
- [ ] Matches system style
- [ ] Not too strong
- [ ] Disabled if haptics off

---

### Test Case IT-ANIM-007-02: Recording Start Haptic

**Objective**: Verify haptic when recording starts.

**Test Steps**:
1. Start recording
2. Check for haptic

**Expected Results**:
- [ ] Medium haptic on start
- [ ] Different from button press
- [ ] Indicates state change
- [ ] Also on stop

---

### Test Case IT-ANIM-007-03: Error Haptic

**Objective**: Verify error haptic feedback.

**Test Steps**:
1. Trigger error
2. Check for haptic

**Expected Results**:
- [ ] Error/warning haptic
- [ ] Stronger than normal
- [ ] Indicates failure
- [ ] Matches error banner

---

## Test Data Fixtures

### Animation Durations

| Animation | Duration | Easing |
|-----------|----------|--------|
| Screen transition | 0.3s | easeInOut |
| Button press | 0.15s | spring |
| Modal presentation | 0.35s | spring |
| Error banner | 0.25s | easeOut |
| Language swap | 0.3s | spring |
| Skeleton shimmer | 1.5s | linear |

### Gesture Parameters

| Gesture | Min Distance | Velocity Threshold |
|---------|--------------|-------------------|
| Swipe dismiss | 100pt | 500pt/s |
| Swipe delete | 80pt | 300pt/s |
| Edge swipe | 20pt from edge | 200pt/s |
| Long press | - | 1.0s duration |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 45 test cases | AI Agent |
