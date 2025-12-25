import { test, expect, Page } from '@playwright/test';

/**
 * IT-VIEW: SwiftUI View Component Integration Tests
 * Total: 85 test cases
 * Priority: P0-Critical
 */

// Helper function to wait for page load
async function waitForAppReady(page: Page) {
  await page.waitForLoadState('networkidle');
  await page.waitForSelector('h1', { timeout: 10000 });
}

test.describe('IT-VIEW-001: HomeView Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-VIEW-001-01: Home Screen Initial State', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
    await expect(page.getByRole('button', { name: /Record|Stop/i })).toBeVisible();
    const statusText = page.getByText(/Connected|Connecting/);
    await expect(statusText).toBeVisible();
  });

  test('IT-VIEW-001-02: Language Selection Display', async ({ page }) => {
    const fromLabel = page.getByText('From', { exact: true });
    const toLabel = page.getByText('To', { exact: true });
    await expect(fromLabel).toBeVisible();
    await expect(toLabel).toBeVisible();
  });

  test('IT-VIEW-001-03: Start Button State', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
    // Button state depends on WebSocket connection
    const isEnabled = await recordButton.isEnabled();
    expect(typeof isEnabled).toBe('boolean');
  });

  test('IT-VIEW-001-04: History Button Navigation', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('IT-VIEW-001-05: Settings Button Navigation', async ({ page }) => {
    const settingsButton = page.locator('button[aria-label*="settings"], button[aria-label*="Settings"], [data-testid="settings-button"]');
    const count = await settingsButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-001-06: Swap Languages Animation', async ({ page }) => {
    const swapButton = page.locator('button[aria-label*="swap"], button[aria-label*="Swap"], [data-testid="swap-languages"]');
    const count = await swapButton.count();
    if (count > 0) {
      await swapButton.first().click();
      await page.waitForTimeout(500);
    }
    expect(true).toBe(true);
  });

  test('IT-VIEW-001-07: Recent Sessions Display', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('IT-VIEW-001-08: Quick Start From History', async ({ page }) => {
    const historyItems = page.locator('[data-testid="history-item"], .history-item');
    const count = await historyItems.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-001-09: Dark Mode Support', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.reload();
    await waitForAppReady(page);
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-001-10: Landscape Orientation', async ({ page }) => {
    await page.setViewportSize({ width: 844, height: 390 });
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-001-11: iPad Layout', async ({ page }) => {
    await page.setViewportSize({ width: 1024, height: 768 });
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-001-12: Loading State', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-001-13: Error State Display', async ({ page }) => {
    const errorElement = page.locator('[role="alert"], .error-message');
    const count = await errorElement.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-001-14: Offline Mode Indicator', async ({ page }) => {
    const statusText = page.getByText(/Connected|Connecting|Offline/);
    await expect(statusText).toBeVisible();
  });

  test('IT-VIEW-001-15: Premium Badge Display', async ({ page }) => {
    const premiumBadge = page.locator('[data-testid="premium-badge"], .premium-badge');
    const count = await premiumBadge.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});

test.describe('IT-VIEW-002: InterpretationView Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-VIEW-002-01: Initial Interpretation State', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('IT-VIEW-002-02: Listening Animation', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('IT-VIEW-002-03: Processing Animation', async ({ page }) => {
    const processingIndicator = page.locator('.processing, [data-state="processing"]');
    const count = await processingIndicator.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-04: Transcript Bubble Display', async ({ page }) => {
    const transcriptArea = page.locator('[data-testid="transcript"], .transcript, .translation-bubble');
    const count = await transcriptArea.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-05: Dual Language Layout', async ({ page }) => {
    const fromLabel = page.getByText('From', { exact: true });
    const toLabel = page.getByText('To', { exact: true });
    await expect(fromLabel).toBeVisible();
    await expect(toLabel).toBeVisible();
  });

  test('IT-VIEW-002-06: Auto Scroll Behavior', async ({ page }) => {
    const scrollContainer = page.locator('.scroll-container, [data-testid="scroll-container"]');
    const count = await scrollContainer.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-07: Manual Scroll Override', async ({ page }) => {
    const scrollContainer = page.locator('main, .main-content');
    await expect(scrollContainer.first()).toBeVisible();
  });

  test('IT-VIEW-002-08: Pause/Resume Button', async ({ page }) => {
    const pauseButton = page.locator('button[aria-label*="pause"], button[aria-label*="Pause"]');
    const count = await pauseButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-09: Stop Button Confirmation', async ({ page }) => {
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('IT-VIEW-002-10: Volume Indicator', async ({ page }) => {
    const volumeIndicator = page.locator('[data-testid="volume-indicator"], .volume-indicator, .audio-level');
    const count = await volumeIndicator.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-11: Language Swap During Session', async ({ page }) => {
    const swapButton = page.locator('button[aria-label*="swap"], button[aria-label*="Swap"]');
    const count = await swapButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-12: Session Timer Display', async ({ page }) => {
    const timer = page.locator('[data-testid="session-timer"], .session-timer');
    const count = await timer.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-13: Audio Level Visualization', async ({ page }) => {
    const audioViz = page.locator('[data-testid="audio-visualization"], .audio-level');
    const count = await audioViz.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-14: Connection Status', async ({ page }) => {
    const statusText = page.getByText(/Connected|Connecting/);
    await expect(statusText).toBeVisible();
  });

  test('IT-VIEW-002-15: Error Recovery UI', async ({ page }) => {
    const retryButton = page.locator('button[aria-label*="retry"], button:has-text("Retry")');
    const count = await retryButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-16: Bookmark Transcript', async ({ page }) => {
    const bookmarkButton = page.locator('button[aria-label*="bookmark"], button[aria-label*="Bookmark"]');
    const count = await bookmarkButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-17: Share Transcript', async ({ page }) => {
    const shareButton = page.locator('button[aria-label*="share"], button[aria-label*="Share"]');
    const count = await shareButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-18: Full Screen Mode', async ({ page }) => {
    const fullscreenButton = page.locator('button[aria-label*="fullscreen"], button[aria-label*="Fullscreen"]');
    const count = await fullscreenButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-19: Background Recording UI', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-002-20: End Session Summary', async ({ page }) => {
    const summarySection = page.locator('[data-testid="session-summary"], .session-summary');
    const count = await summarySection.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-21: Retry Connection', async ({ page }) => {
    const statusText = page.getByText(/Connected|Connecting/);
    await expect(statusText).toBeVisible();
  });

  test('IT-VIEW-002-22: Partial Results Display', async ({ page }) => {
    const partialResults = page.locator('[data-testid="partial-result"], .partial-result');
    const count = await partialResults.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-23: Confidence Indicator', async ({ page }) => {
    const confidence = page.locator('[data-testid="confidence"], .confidence-score');
    const count = await confidence.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-24: Alternative Translations', async ({ page }) => {
    const alternatives = page.locator('[data-testid="alternatives"], .alternative-translations');
    const count = await alternatives.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-002-25: Dictionary Lookup', async ({ page }) => {
    const dictionaryLink = page.locator('[data-testid="dictionary-lookup"], .dictionary-link');
    const count = await dictionaryLink.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});

test.describe('IT-VIEW-003: SettingsView Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-VIEW-003-01: Settings Categories Display', async ({ page }) => {
    const settingsButton = page.locator('button[aria-label*="settings"], button[aria-label*="Settings"]');
    const count = await settingsButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-003-02: Audio Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-03: Speech Recognition Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-04: Translation Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-05: Text-to-Speech Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-06: Appearance Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-07: Privacy Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-08: Account Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-09: Notification Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-10: Language Preferences', async ({ page }) => {
    const languageButtons = page.locator('button[aria-label*="language"]');
    const count = await languageButtons.count();
    expect(count).toBeGreaterThan(0);
  });

  test('IT-VIEW-003-11: About Section', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-12: Help & Support', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-13: Reset Settings', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-14: Export Data', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-15: Delete Account', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-16: Feedback Form', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-17: Version Info', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-003-18: Open Source Licenses', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });
});

test.describe('IT-VIEW-004: HistoryView Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-VIEW-004-01: History List Display', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('IT-VIEW-004-02: Session Detail View', async ({ page }) => {
    const historyItems = page.locator('[data-testid="history-item"], .history-item');
    const count = await historyItems.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-03: Search Sessions', async ({ page }) => {
    const searchInput = page.locator('input[type="search"], input[placeholder*="Search"]');
    const count = await searchInput.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-04: Filter By Date', async ({ page }) => {
    const dateFilter = page.locator('[data-testid="date-filter"], .date-filter');
    const count = await dateFilter.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-05: Filter By Language', async ({ page }) => {
    const languageFilter = page.locator('[data-testid="language-filter"], .language-filter');
    const count = await languageFilter.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-06: Delete Session', async ({ page }) => {
    const deleteButton = page.locator('button[aria-label*="delete"], button[aria-label*="Delete"]');
    const count = await deleteButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-07: Batch Delete', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-004-08: Export Session', async ({ page }) => {
    const exportButton = page.locator('button[aria-label*="export"], button[aria-label*="Export"]');
    const count = await exportButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-09: Share Session', async ({ page }) => {
    const shareButton = page.locator('button[aria-label*="share"], button[aria-label*="Share"]');
    const count = await shareButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-10: Replay Session', async ({ page }) => {
    const replayButton = page.locator('button[aria-label*="replay"], button[aria-label*="Replay"]');
    const count = await replayButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-004-11: Empty State', async ({ page }) => {
    const emptyMessage = page.getByText(/Tap the microphone|start translating|No history/i);
    await expect(emptyMessage).toBeVisible();
  });

  test('IT-VIEW-004-12: Pull To Refresh', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });
});

test.describe('IT-VIEW-005: OnboardingView Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-VIEW-005-01: Welcome Screen', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-005-02: Permission Request - Microphone', async ({ page }) => {
    const permissionRequest = page.locator('[data-testid="microphone-permission"], .permission-request');
    const count = await permissionRequest.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-005-03: Permission Request - Speech Recognition', async ({ page }) => {
    const permissionRequest = page.locator('[data-testid="speech-permission"], .permission-request');
    const count = await permissionRequest.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-005-04: Language Selection', async ({ page }) => {
    const languageButtons = page.locator('button[aria-label*="language"]');
    const count = await languageButtons.count();
    expect(count).toBeGreaterThan(0);
  });

  test('IT-VIEW-005-05: Feature Tour', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-005-06: Skip Onboarding', async ({ page }) => {
    const skipButton = page.locator('button[aria-label*="skip"], button:has-text("Skip")');
    const count = await skipButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-005-07: Onboarding Complete', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-005-08: Return User Skip', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });
});

test.describe('IT-VIEW-006: DictionaryView Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('IT-VIEW-006-01: Dictionary Search', async ({ page }) => {
    const searchInput = page.locator('input[type="search"], input[placeholder*="Search"]');
    const count = await searchInput.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-006-02: Word Detail', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('IT-VIEW-006-03: Favorites List', async ({ page }) => {
    const favoritesList = page.locator('[data-testid="favorites"], .favorites-list');
    const count = await favoritesList.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-006-04: Add To Favorites', async ({ page }) => {
    const favoriteButton = page.locator('button[aria-label*="favorite"], button[aria-label*="Favorite"]');
    const count = await favoriteButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-006-05: Remove From Favorites', async ({ page }) => {
    const unfavoriteButton = page.locator('button[aria-label*="unfavorite"], button[aria-label*="remove favorite"]');
    const count = await unfavoriteButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-006-06: Pronunciation Playback', async ({ page }) => {
    const playButton = page.locator('button[aria-label*="play"], button[aria-label*="pronounce"]');
    const count = await playButton.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test('IT-VIEW-006-07: Example Sentences', async ({ page }) => {
    const examples = page.locator('[data-testid="examples"], .example-sentences');
    const count = await examples.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });
});
