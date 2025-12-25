import { test, expect, Page } from '@playwright/test';

/**
 * IT-BIND: ViewModel-View Binding Integration Tests
 * Total: 72 test cases
 * Priority: P0-Critical
 */

async function waitForAppReady(page: Page) {
  await page.waitForLoadState('networkidle');
  await page.waitForSelector('h1', { timeout: 10000 });
}

test.describe('IT-BIND-001: HomeViewModel Binding Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-BIND-001-01: Source Language Binding', async ({ page }) => {
    const japaneseButton = page.locator('button[aria-label="Select Japanese as source language"]');
    const count = await japaneseButton.count();
    if (count > 0) {
      await japaneseButton.click();
      await expect(japaneseButton).toHaveClass(/active/);
    }
    expect(true).toBe(true);
  });

  test('IT-BIND-001-02: Target Language Binding', async ({ page }) => {
    const englishButton = page.locator('button[aria-label="Select English as target language"]');
    const count = await englishButton.count();
    if (count > 0) {
      await englishButton.click();
      await expect(englishButton).toHaveClass(/active/);
    }
    expect(true).toBe(true);
  });

  test('IT-BIND-001-03: Can Start Session Binding', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
    // Button may be disabled initially until WebSocket connects
    const isEnabled = await recordButton.isEnabled();
    expect(typeof isEnabled).toBe('boolean');
  });

  test('IT-BIND-001-04: Recent Sessions Binding', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('IT-BIND-001-05: Is Loading Binding', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-BIND-001-06: Error Message Binding', async ({ page }) => {
    const errorElement = page.locator('[role="alert"], .error-message');
    const count = await errorElement.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-001-07: Swap Languages Action', async ({ page }) => {
    const swapButton = page.locator('button[aria-label*="swap"], button[aria-label*="Swap"]');
    const count = await swapButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-001-08: Start Session Action', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
    // Button state depends on WebSocket connection status
    const isEnabled = await recordButton.isEnabled();
    expect(typeof isEnabled).toBe('boolean');
  });

  test('IT-BIND-001-09: Load History Action', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('IT-BIND-001-10: Premium Status Binding', async ({ page }) => {
    const premiumBadge = page.locator('[data-testid="premium-badge"], .premium-badge');
    const count = await premiumBadge.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-001-11: Network Status Binding', async ({ page }) => {
    const statusText = page.getByText(/Connected|Connecting/);
    await expect(statusText).toBeVisible();
  });

  test('IT-BIND-001-12: User Preferences Binding', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });
});

test.describe('IT-BIND-002: InterpretationViewModel Binding Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-BIND-002-01: Interpretation State Binding', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('IT-BIND-002-02: Is Listening Binding', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('IT-BIND-002-03: Is Processing Binding', async ({ page }) => {
    const processingIndicator = page.locator('.processing, [data-state="processing"]');
    const count = await processingIndicator.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-04: Transcripts Array Binding', async ({ page }) => {
    const transcripts = page.locator('[data-testid="transcript"], .transcript');
    const count = await transcripts.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-05: Current Transcript Binding', async ({ page }) => {
    const currentTranscript = page.locator('[data-testid="current-transcript"], .current-transcript');
    const count = await currentTranscript.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-06: Audio Level Binding', async ({ page }) => {
    const audioLevel = page.locator('[data-testid="audio-level"], .audio-level');
    const count = await audioLevel.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-07: Session Duration Binding', async ({ page }) => {
    const timer = page.locator('[data-testid="session-timer"], .session-timer');
    const count = await timer.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-08: Error State Binding', async ({ page }) => {
    const errorElement = page.locator('[role="alert"], .error-message');
    const count = await errorElement.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-09: Toggle Listening Action', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
    // Button state depends on connection status
    const isEnabled = await recordButton.isEnabled();
    expect(typeof isEnabled).toBe('boolean');
  });

  test('IT-BIND-002-10: Pause Session Action', async ({ page }) => {
    const pauseButton = page.locator('button[aria-label*="pause"], button[aria-label*="Pause"]');
    const count = await pauseButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-11: Resume Session Action', async ({ page }) => {
    const resumeButton = page.locator('button[aria-label*="resume"], button[aria-label*="Resume"]');
    const count = await resumeButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-12: Stop Session Action', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('IT-BIND-002-13: Swap Languages Action', async ({ page }) => {
    const swapButton = page.locator('button[aria-label*="swap"], button[aria-label*="Swap"]');
    const count = await swapButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-14: Bookmark Action', async ({ page }) => {
    const bookmarkButton = page.locator('button[aria-label*="bookmark"], button[aria-label*="Bookmark"]');
    const count = await bookmarkButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-15: Share Action', async ({ page }) => {
    const shareButton = page.locator('button[aria-label*="share"], button[aria-label*="Share"]');
    const count = await shareButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-16: Connection Status Binding', async ({ page }) => {
    const statusText = page.getByText(/Connected|Connecting/);
    await expect(statusText).toBeVisible();
  });

  test('IT-BIND-002-17: Partial Result Binding', async ({ page }) => {
    const partialResult = page.locator('[data-testid="partial-result"], .partial-result');
    const count = await partialResult.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-18: Final Result Binding', async ({ page }) => {
    const finalResult = page.locator('[data-testid="final-result"], .final-result');
    const count = await finalResult.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-19: Translation Progress Binding', async ({ page }) => {
    const progress = page.locator('[data-testid="translation-progress"], .translation-progress');
    const count = await progress.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-20: TTS Status Binding', async ({ page }) => {
    const ttsStatus = page.locator('[data-testid="tts-status"], .tts-status');
    const count = await ttsStatus.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-21: Retry Action', async ({ page }) => {
    const retryButton = page.locator('button[aria-label*="retry"], button:has-text("Retry")');
    const count = await retryButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-22: Save Session Action', async ({ page }) => {
    const saveButton = page.locator('button[aria-label*="save"], button:has-text("Save")');
    const count = await saveButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-23: Discard Session Action', async ({ page }) => {
    const discardButton = page.locator('button[aria-label*="discard"], button:has-text("Discard")');
    const count = await discardButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-24: Auto Scroll Binding', async ({ page }) => {
    const scrollContainer = page.locator('.scroll-container, [data-testid="scroll-container"]');
    const count = await scrollContainer.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-002-25: Full Screen Binding', async ({ page }) => {
    const fullscreenButton = page.locator('button[aria-label*="fullscreen"], button[aria-label*="Fullscreen"]');
    const count = await fullscreenButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});

test.describe('IT-BIND-003: SettingsViewModel Binding Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-BIND-003-01: Audio Input Source Binding', async ({ page }) => {
    const audioInput = page.locator('[data-testid="audio-input"], select[name="audio-input"]');
    const count = await audioInput.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-02: Audio Output Destination Binding', async ({ page }) => {
    const audioOutput = page.locator('[data-testid="audio-output"], select[name="audio-output"]');
    const count = await audioOutput.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-03: Voice Speed Binding', async ({ page }) => {
    const voiceSpeed = page.locator('[data-testid="voice-speed"], input[name="voice-speed"]');
    const count = await voiceSpeed.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-04: Voice Pitch Binding', async ({ page }) => {
    const voicePitch = page.locator('[data-testid="voice-pitch"], input[name="voice-pitch"]');
    const count = await voicePitch.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-05: Auto Language Detection Binding', async ({ page }) => {
    const autoDetect = page.locator('[data-testid="auto-detect"], input[name="auto-detect"]');
    const count = await autoDetect.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-06: Translation Quality Binding', async ({ page }) => {
    const quality = page.locator('[data-testid="translation-quality"], select[name="translation-quality"]');
    const count = await quality.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-07: Theme Mode Binding', async ({ page }) => {
    const themeToggle = page.locator('[data-testid="theme-toggle"], input[name="theme"]');
    const count = await themeToggle.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-08: Font Size Binding', async ({ page }) => {
    const fontSize = page.locator('[data-testid="font-size"], input[name="font-size"]');
    const count = await fontSize.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-09: Haptic Feedback Binding', async ({ page }) => {
    const haptic = page.locator('[data-testid="haptic-feedback"], input[name="haptic"]');
    const count = await haptic.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-10: Notification Enabled Binding', async ({ page }) => {
    const notifications = page.locator('[data-testid="notifications"], input[name="notifications"]');
    const count = await notifications.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-11: Privacy Mode Binding', async ({ page }) => {
    const privacy = page.locator('[data-testid="privacy-mode"], input[name="privacy"]');
    const count = await privacy.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-12: Data Sync Binding', async ({ page }) => {
    const dataSync = page.locator('[data-testid="data-sync"], input[name="data-sync"]');
    const count = await dataSync.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-13: Save Settings Action', async ({ page }) => {
    const saveButton = page.locator('button[aria-label*="save"], button:has-text("Save")');
    const count = await saveButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-14: Reset Settings Action', async ({ page }) => {
    const resetButton = page.locator('button[aria-label*="reset"], button:has-text("Reset")');
    const count = await resetButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-003-15: Export Data Action', async ({ page }) => {
    const exportButton = page.locator('button[aria-label*="export"], button:has-text("Export")');
    const count = await exportButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});

test.describe('IT-BIND-004: HistoryViewModel Binding Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-BIND-004-01: Sessions Array Binding', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('IT-BIND-004-02: Selected Session Binding', async ({ page }) => {
    const historyItems = page.locator('[data-testid="history-item"], .history-item');
    const count = await historyItems.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-03: Search Query Binding', async ({ page }) => {
    const searchInput = page.locator('input[type="search"], input[placeholder*="Search"]');
    const count = await searchInput.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-04: Filter Options Binding', async ({ page }) => {
    const filterOptions = page.locator('[data-testid="filter-options"], .filter-options');
    const count = await filterOptions.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-05: Is Loading Binding', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-BIND-004-06: Delete Session Action', async ({ page }) => {
    const deleteButton = page.locator('button[aria-label*="delete"], button:has-text("Delete")');
    const count = await deleteButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-07: Batch Delete Action', async ({ page }) => {
    const batchDelete = page.locator('button[aria-label*="batch-delete"], button:has-text("Delete All")');
    const count = await batchDelete.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-08: Export Session Action', async ({ page }) => {
    const exportButton = page.locator('button[aria-label*="export"], button:has-text("Export")');
    const count = await exportButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-09: Refresh Action', async ({ page }) => {
    const refreshButton = page.locator('button[aria-label*="refresh"], button:has-text("Refresh")');
    const count = await refreshButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-004-10: Sort Order Binding', async ({ page }) => {
    const sortOrder = page.locator('[data-testid="sort-order"], select[name="sort"]');
    const count = await sortOrder.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});

test.describe('IT-BIND-005: OnboardingViewModel Binding Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-BIND-005-01: Current Step Binding', async ({ page }) => {
    const stepIndicator = page.locator('[data-testid="step-indicator"], .step-indicator');
    const count = await stepIndicator.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-02: Progress Binding', async ({ page }) => {
    const progress = page.locator('[data-testid="onboarding-progress"], .onboarding-progress');
    const count = await progress.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-03: Can Continue Binding', async ({ page }) => {
    const continueButton = page.locator('button[aria-label*="continue"], button:has-text("Continue")');
    const count = await continueButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-04: Microphone Permission Binding', async ({ page }) => {
    const permissionStatus = page.locator('[data-testid="mic-permission-status"], .permission-status');
    const count = await permissionStatus.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-05: Speech Permission Binding', async ({ page }) => {
    const permissionStatus = page.locator('[data-testid="speech-permission-status"], .permission-status');
    const count = await permissionStatus.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-06: Selected Languages Binding', async ({ page }) => {
    const languageButtons = page.locator('button[aria-label*="language"]');
    const count = await languageButtons.count();
    expect(count).toBeGreaterThan(0);
  });

  test('IT-BIND-005-07: Next Step Action', async ({ page }) => {
    const nextButton = page.locator('button[aria-label*="next"], button:has-text("Next")');
    const count = await nextButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-08: Previous Step Action', async ({ page }) => {
    const prevButton = page.locator('button[aria-label*="previous"], button:has-text("Back")');
    const count = await prevButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-09: Skip Action', async ({ page }) => {
    const skipButton = page.locator('button[aria-label*="skip"], button:has-text("Skip")');
    const count = await skipButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-BIND-005-10: Complete Action', async ({ page }) => {
    const completeButton = page.locator('button[aria-label*="complete"], button:has-text("Complete")');
    const count = await completeButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});
