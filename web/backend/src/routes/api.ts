import { Router, Request, Response } from 'express';
import { GeminiService } from '../services/gemini';

export function createApiRouter(geminiService: GeminiService): Router {
  const router = Router();

  /**
   * Health check endpoint
   */
  router.get('/health', (req: Request, res: Response) => {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'LiveLingo Backend',
      version: '1.0.0',
    });
  });

  /**
   * Get supported languages
   */
  router.get('/languages', (req: Request, res: Response) => {
    const languages = [
      { code: 'en', name: 'English' },
      { code: 'ja', name: 'Japanese' },
      { code: 'es', name: 'Spanish' },
      { code: 'fr', name: 'French' },
      { code: 'de', name: 'German' },
      { code: 'it', name: 'Italian' },
      { code: 'pt', name: 'Portuguese' },
      { code: 'ru', name: 'Russian' },
      { code: 'zh', name: 'Chinese' },
      { code: 'ko', name: 'Korean' },
      { code: 'ar', name: 'Arabic' },
      { code: 'hi', name: 'Hindi' },
    ];

    res.json({ languages });
  });

  /**
   * Translate text (REST API alternative to WebSocket)
   */
  router.post('/translate', async (req: Request, res: Response) => {
    try {
      const { text, targetLanguage, sourceLanguage } = req.body;

      if (!text || !targetLanguage) {
        return res.status(400).json({
          error: 'Missing required fields: text, targetLanguage',
        });
      }

      const result = await geminiService.translateText(
        text,
        targetLanguage,
        sourceLanguage
      );

      res.json(result);
    } catch (error) {
      console.error('Translation error:', error);
      res.status(500).json({
        error: 'Translation failed',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  /**
   * Get service statistics
   */
  router.get('/stats', (req: Request, res: Response) => {
    // This would typically fetch from a database or metrics service
    res.json({
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      platform: process.platform,
      nodeVersion: process.version,
    });
  });

  /**
   * Test Gemini connection
   */
  router.get('/test-gemini', async (req: Request, res: Response) => {
    try {
      const testResult = await geminiService.translateText(
        'Hello, world!',
        'Japanese'
      );

      res.json({
        status: 'success',
        message: 'Gemini API is working',
        test: testResult,
      });
    } catch (error) {
      res.status(500).json({
        status: 'error',
        message: 'Gemini API test failed',
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  });

  return router;
}
