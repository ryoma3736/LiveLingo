/**
 * LiveLingo E2E Authentication Helper
 * Generated: 2024-12-25
 *
 * Helper functions for test authentication.
 */

import { Page, BrowserContext } from '@playwright/test';
import { TEST_ADMIN, TEST_USER, TEST_GUEST, TestUser, TEST_SESSIONS } from '../fixtures/test-users';

/**
 * Login with test credentials
 */
export async function loginAsTestUser(
  page: Page,
  user: TestUser = TEST_USER
): Promise<void> {
  // Navigate to login page
  await page.goto('/login');

  // Wait for login form
  await page.waitForSelector('[data-testid="login-form"]', { timeout: 10000 });

  // Fill credentials
  await page.fill('[data-testid="email-input"]', user.email);
  await page.fill('[data-testid="password-input"]', user.password);

  // Submit
  await page.click('[data-testid="login-button"]');

  // Wait for navigation to home
  await page.waitForURL('/', { timeout: 10000 });
}

/**
 * Login as admin user
 */
export async function loginAsAdmin(page: Page): Promise<void> {
  await loginAsTestUser(page, TEST_ADMIN);
}

/**
 * Login as standard user
 */
export async function loginAsUser(page: Page): Promise<void> {
  await loginAsTestUser(page, TEST_USER);
}

/**
 * Login as guest user
 */
export async function loginAsGuest(page: Page): Promise<void> {
  await loginAsTestUser(page, TEST_GUEST);
}

/**
 * Set authentication cookies directly (for faster tests)
 */
export async function setAuthCookies(
  context: BrowserContext,
  role: 'admin' | 'user' | 'guest' = 'user'
): Promise<void> {
  const session = TEST_SESSIONS[role];
  const user = role === 'admin' ? TEST_ADMIN : role === 'guest' ? TEST_GUEST : TEST_USER;

  await context.addCookies([
    {
      name: 'auth_token',
      value: session.token,
      domain: 'localhost',
      path: '/',
      httpOnly: true,
      secure: false,
      sameSite: 'Lax',
    },
    {
      name: 'refresh_token',
      value: session.refreshToken,
      domain: 'localhost',
      path: '/',
      httpOnly: true,
      secure: false,
      sameSite: 'Lax',
    },
    {
      name: 'user_id',
      value: user.id,
      domain: 'localhost',
      path: '/',
      httpOnly: false,
      secure: false,
      sameSite: 'Lax',
    },
  ]);
}

/**
 * Set localStorage auth state
 */
export async function setAuthLocalStorage(
  page: Page,
  role: 'admin' | 'user' | 'guest' = 'user'
): Promise<void> {
  const session = TEST_SESSIONS[role];
  const user = role === 'admin' ? TEST_ADMIN : role === 'guest' ? TEST_GUEST : TEST_USER;

  await page.evaluate(({ user, session }) => {
    localStorage.setItem('auth_state', JSON.stringify({
      isAuthenticated: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
      token: session.token,
      expiresAt: session.expiresAt,
    }));
  }, { user, session });
}

/**
 * Logout current user
 */
export async function logout(page: Page): Promise<void> {
  // Click user menu
  await page.click('[data-testid="user-menu"]');

  // Click logout
  await page.click('[data-testid="logout-button"]');

  // Wait for redirect to login
  await page.waitForURL('/login', { timeout: 10000 });
}

/**
 * Clear all auth state
 */
export async function clearAuthState(
  page: Page,
  context: BrowserContext
): Promise<void> {
  // Clear cookies
  await context.clearCookies();

  // Clear localStorage
  await page.evaluate(() => {
    localStorage.removeItem('auth_state');
    localStorage.removeItem('user_preferences');
  });
}

/**
 * Check if user is authenticated
 */
export async function isAuthenticated(page: Page): Promise<boolean> {
  const authState = await page.evaluate(() => {
    return localStorage.getItem('auth_state');
  });

  if (!authState) return false;

  try {
    const state = JSON.parse(authState);
    return state.isAuthenticated === true;
  } catch {
    return false;
  }
}

/**
 * Wait for authentication to complete
 */
export async function waitForAuth(page: Page, timeout = 10000): Promise<void> {
  await page.waitForFunction(
    () => {
      const state = localStorage.getItem('auth_state');
      if (!state) return false;
      try {
        return JSON.parse(state).isAuthenticated === true;
      } catch {
        return false;
      }
    },
    { timeout }
  );
}

/**
 * Mock Sign in with Apple response
 */
export async function mockAppleSignIn(page: Page): Promise<void> {
  await page.route('**/api/auth/apple', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        user: {
          id: TEST_USER.id,
          email: TEST_USER.email,
          name: TEST_USER.name,
        },
        token: TEST_SESSIONS.user.token,
        refreshToken: TEST_SESSIONS.user.refreshToken,
        expiresAt: TEST_SESSIONS.user.expiresAt,
      }),
    });
  });
}

/**
 * Mock biometric authentication
 */
export async function mockBiometricAuth(
  page: Page,
  success: boolean = true
): Promise<void> {
  await page.route('**/api/auth/biometric', async (route) => {
    if (success) {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          success: true,
          authenticated: true,
        }),
      });
    } else {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          success: false,
          error: 'Biometric authentication failed',
        }),
      });
    }
  });
}
