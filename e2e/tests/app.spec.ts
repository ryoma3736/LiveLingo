import { test, expect } from '@playwright/test';

test.describe('LiveLingo Application', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display the main page with title', async ({ page }) => {
    await expect(page).toHaveTitle(/LiveLingo/);
    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('should show connection status indicator', async ({ page }) => {
    // Check for connection status element - new design uses "Connecting..." or "Connected"
    const statusText = page.getByText(/Connected|Connecting/);
    await expect(statusText).toBeVisible();
  });

  test('should display language selection buttons', async ({ page }) => {
    // New design uses button pills instead of dropdowns
    const fromLabel = page.getByText('From', { exact: true });
    await expect(fromLabel).toBeVisible();

    const toLabel = page.getByText('To', { exact: true });
    await expect(toLabel).toBeVisible();
  });

  test('should have record button visible', async ({ page }) => {
    // Find the record button
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('should be able to select source language', async ({ page }) => {
    // Find and click Japanese as source language by aria-label
    const japaneseButton = page.locator('button[aria-label="Select Japanese as source language"]');
    await japaneseButton.click();
    // Verify it's now active
    await expect(japaneseButton).toHaveClass(/active/);
  });

  test('should be able to select target language', async ({ page }) => {
    // Find and click English as target language by aria-label
    const englishButton = page.locator('button[aria-label="Select English as target language"]');
    await englishButton.click();
    // Verify it's now active
    await expect(englishButton).toHaveClass(/active/);
  });

  test('should show history section', async ({ page }) => {
    const historySection = page.getByText('History');
    await expect(historySection).toBeVisible();
  });

  test('should show empty state message when no translations', async ({ page }) => {
    const emptyMessage = page.getByText(/Tap the microphone|start translating/i);
    await expect(emptyMessage).toBeVisible();
  });
});

test.describe('Responsive Design', () => {
  test('should display correctly on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');

    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('should display correctly on tablet', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');

    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });

  test('should display correctly on desktop', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');

    await expect(page.getByRole('heading', { name: /LiveLingo/i })).toBeVisible();
  });
});

test.describe('Accessibility', () => {
  test('should have proper heading hierarchy', async ({ page }) => {
    await page.goto('/');

    const h1 = page.locator('h1');
    await expect(h1).toHaveCount(1);
  });

  test('should have accessible buttons', async ({ page }) => {
    await page.goto('/');

    const buttons = page.getByRole('button');
    const buttonCount = await buttons.count();
    expect(buttonCount).toBeGreaterThan(0);
  });

  test('should have aria labels on language buttons', async ({ page }) => {
    await page.goto('/');

    // Check that language buttons have aria-labels
    const ariaButtons = page.locator('button[aria-label*="language"]');
    const count = await ariaButtons.count();
    expect(count).toBeGreaterThan(0);
  });
});
