/**
 * LiveLingo E2E Test User Fixtures
 * Generated: 2024-12-25
 *
 * Test credentials for integration testing.
 * DO NOT use in production environment.
 */

export interface TestUser {
  id: string;
  email: string;
  password: string;
  name: string;
  role: 'admin' | 'user' | 'guest';
  permissions: string[];
}

/**
 * Primary Test User - Full Admin Access
 * Use for: Admin functionality tests, full feature access
 */
export const TEST_ADMIN: TestUser = {
  id: 'test-user-001',
  email: 'test.admin@livelingo.test',
  password: 'LiveLingo@Test2024!',
  name: 'Test Administrator',
  role: 'admin',
  permissions: [
    'interpretation:full',
    'settings:all',
    'history:all',
    'glossary:manage',
    'voice:all',
    'export:all',
    'admin:users',
  ],
};

/**
 * Standard Test User - Normal Access
 * Use for: Standard user flow tests
 */
export const TEST_USER: TestUser = {
  id: 'test-user-002',
  email: 'test.user@livelingo.test',
  password: 'LiveLingo@User2024!',
  name: 'Test User',
  role: 'user',
  permissions: [
    'interpretation:full',
    'settings:personal',
    'history:own',
    'glossary:use',
    'voice:select',
    'export:own',
  ],
};

/**
 * Guest Test User - Limited Access
 * Use for: Guest/trial functionality tests
 */
export const TEST_GUEST: TestUser = {
  id: 'test-guest-001',
  email: 'test.guest@livelingo.test',
  password: 'LiveLingo@Guest2024!',
  name: 'Test Guest',
  role: 'guest',
  permissions: [
    'interpretation:limited',
    'settings:basic',
  ],
};

/**
 * All test users for iteration
 */
export const ALL_TEST_USERS: TestUser[] = [
  TEST_ADMIN,
  TEST_USER,
  TEST_GUEST,
];

/**
 * Test Session Tokens (Pre-generated for testing)
 */
export const TEST_SESSIONS = {
  admin: {
    token: 'test-jwt-admin-token-2024-mock',
    refreshToken: 'test-refresh-admin-token-2024-mock',
    expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
  },
  user: {
    token: 'test-jwt-user-token-2024-mock',
    refreshToken: 'test-refresh-user-token-2024-mock',
    expiresAt: new Date(Date.now() + 3600 * 1000).toISOString(),
  },
  guest: {
    token: 'test-jwt-guest-token-2024-mock',
    refreshToken: 'test-refresh-guest-token-2024-mock',
    expiresAt: new Date(Date.now() + 1800 * 1000).toISOString(),
  },
  expired: {
    token: 'test-jwt-expired-token-2024-mock',
    refreshToken: 'test-refresh-expired-token-2024-mock',
    expiresAt: new Date(Date.now() - 3600 * 1000).toISOString(),
  },
};

/**
 * Mock Apple ID Credentials (for Sign in with Apple tests)
 */
export const MOCK_APPLE_CREDENTIALS = {
  validUser: {
    userIdentifier: 'apple-test-user-001',
    email: 'hidden-email@privaterelay.appleid.com',
    fullName: {
      givenName: 'Apple',
      familyName: 'TestUser',
    },
    authorizationCode: 'mock-auth-code-12345',
    identityToken: 'mock-identity-token-12345',
  },
  revokedUser: {
    userIdentifier: 'apple-revoked-user-001',
    state: 'revoked',
  },
};

/**
 * Test API Keys (Mock - for testing only)
 */
export const MOCK_API_KEYS = {
  gemini: {
    valid: 'test-gemini-api-key-mock-12345',
    invalid: 'invalid-gemini-key',
    rateLimited: 'rate-limited-gemini-key',
  },
  coefont: {
    accessKey: 'test-coefont-access-key-mock',
    clientSecret: 'test-coefont-secret-mock',
    invalid: 'invalid-coefont-key',
  },
};

/**
 * Get test user by role
 */
export function getTestUser(role: 'admin' | 'user' | 'guest'): TestUser {
  switch (role) {
    case 'admin':
      return TEST_ADMIN;
    case 'user':
      return TEST_USER;
    case 'guest':
      return TEST_GUEST;
    default:
      return TEST_USER;
  }
}

/**
 * Get test session by role
 */
export function getTestSession(role: 'admin' | 'user' | 'guest' | 'expired') {
  return TEST_SESSIONS[role];
}
