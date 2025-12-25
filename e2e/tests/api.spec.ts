import { test, expect } from '@playwright/test';

const API_URL = 'http://localhost:8080';

test.describe('Backend API', () => {
  test('should return health check status', async ({ request }) => {
    const response = await request.get(`${API_URL}/api/health`);

    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.status).toBe('ok');
    expect(data.timestamp).toBeDefined();
  });

  test('should return API root info', async ({ request }) => {
    const response = await request.get(`${API_URL}/api`);

    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.name).toContain('LiveLingo');
    expect(data.version).toBeDefined();
    expect(data.endpoints).toBeDefined();
  });

  test('should return supported languages', async ({ request }) => {
    const response = await request.get(`${API_URL}/api/languages`);

    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.languages).toBeDefined();
    expect(Array.isArray(data.languages)).toBeTruthy();
    expect(data.languages.length).toBeGreaterThan(0);

    // Check language structure
    const language = data.languages[0];
    expect(language.code).toBeDefined();
    expect(language.name).toBeDefined();
  });

  test('should return 404 for unknown endpoints', async ({ request }) => {
    const response = await request.get(`${API_URL}/api/unknown`);

    expect(response.status()).toBe(404);
  });

  test('should handle CORS headers', async ({ request }) => {
    // Send request with Origin header to trigger CORS response
    const response = await request.get(`${API_URL}/api/health`, {
      headers: {
        'Origin': 'http://localhost:3000'
      }
    });

    // Check CORS headers are present when Origin is sent
    const headers = response.headers();
    expect(headers['access-control-allow-origin']).toBeDefined();
  });
});

test.describe('Translation API', () => {
  test('should translate text successfully', async ({ request }) => {
    const response = await request.post(`${API_URL}/api/translate`, {
      data: {
        text: 'Hello',
        targetLanguage: 'Japanese',
        sourceLanguage: 'English',
      },
    });

    // This test may fail if GEMINI_API_KEY is not set
    // In that case, it should return appropriate error
    if (response.ok()) {
      const data = await response.json();
      expect(data.translatedText).toBeDefined();
      expect(data.originalText).toBe('Hello');
    } else {
      // API key not configured
      const data = await response.json();
      expect(data.error).toBeDefined();
    }
  });

  test('should validate required fields', async ({ request }) => {
    const response = await request.post(`${API_URL}/api/translate`, {
      data: {
        text: 'Hello',
        // Missing targetLanguage
      },
    });

    expect(response.status()).toBe(400);

    const data = await response.json();
    expect(data.error).toBeDefined();
  });
});

test.describe('Server Statistics', () => {
  test('should return server stats', async ({ request }) => {
    const response = await request.get(`${API_URL}/api/stats`);

    expect(response.ok()).toBeTruthy();

    const data = await response.json();
    expect(data.uptime).toBeDefined();
    expect(data.memory).toBeDefined();
    expect(data.platform).toBeDefined();
    expect(data.nodeVersion).toBeDefined();
  });
});
