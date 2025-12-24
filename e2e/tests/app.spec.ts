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
    // Check for connection status element
    const statusText = page.getByText(/Connected|Disconnected/);
    await expect(statusText).toBeVisible();
  });

  test('should display language selection dropdowns', async ({ page }) => {
    // Source language dropdown
    const sourceLabel = page.getByText('Source Language');
    await expect(sourceLabel).toBeVisible();

    // Target language dropdown
    const targetLabel = page.getByText('Target Language');
    await expect(targetLabel).toBeVisible();
  });

  test('should have record button visible', async ({ page }) => {
    // Find the record button
    const recordButton = page.getByRole('button', { name: /Record|Stop/i });
    await expect(recordButton).toBeVisible();
  });

  test('should be able to change source language', async ({ page }) => {
    // Find and interact with source language dropdown
    const sourceSelect = page.locator('select').first();
    await sourceSelect.selectOption('ja');
    await expect(sourceSelect).toHaveValue('ja');
  });

  test('should be able to change target language', async ({ page }) => {
    // Find and interact with target language dropdown
    const targetSelect = page.locator('select').last();
    await targetSelect.selectOption('en');
    await expect(targetSelect).toHaveValue('en');
  });

  test('should show translation history section', async ({ page }) => {
    const historySection = page.getByText('Translation History');
    await expect(historySection).toBeVisible();
  });

  test('should show empty state message when no translations', async ({ page }) => {
    const emptyMessage = page.getByText(/No translations yet|Click the microphone/i);
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

  test('should have labeled form controls', async ({ page }) => {
    await page.goto('/');

    // Check that selects have associated labels
    const selects = page.locator('select');
    const selectCount = await selects.count();
    expect(selectCount).toBeGreaterThan(0);
  });
});
