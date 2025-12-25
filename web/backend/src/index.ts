import express, { Request, Response } from 'express';
import { createServer } from 'http';
import cors from 'cors';
import dotenv from 'dotenv';
import { prisma, checkDatabaseConnection, getDatabaseHealth } from './lib/prisma';
import { createApiRouter } from './routes/api';
import { WebSocketService } from './services/websocket';
import { GeminiService } from './services/gemini';

// Load environment variables
dotenv.config();

const app = express();
const server = createServer(app);
const PORT = process.env.PORT || 3001;

// CORS configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [
  'http://localhost:3000',
  'http://localhost:5173',
  'http://localhost:8080',
];

// Middleware
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes(origin) || process.env.NODE_ENV === 'development') {
      callback(null, true);
    } else {
      callback(null, true); // Allow all origins for now
    }
  },
  credentials: true,
  exposedHeaders: ['Access-Control-Allow-Origin'],
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Initialize GeminiService and WebSocket service
let wsService: WebSocketService | null = null;
let geminiService: GeminiService | null = null;

if (process.env.GEMINI_API_KEY) {
  geminiService = new GeminiService(process.env.GEMINI_API_KEY);
  wsService = new WebSocketService(server, process.env.GEMINI_API_KEY);
  console.log('✅ Gemini service and WebSocket initialized');
} else {
  console.warn('⚠️  GEMINI_API_KEY not found - Gemini/WebSocket features disabled');
}

// API Routes - mount routes from routes/api.ts if geminiService exists
const apiRouter = express.Router();
if (geminiService) {
  const geminiApiRouter = createApiRouter(geminiService);
  apiRouter.use('/', geminiApiRouter);
}

// Health check endpoint
apiRouter.get('/health', async (_req: Request, res: Response) => {
  const dbHealth = await getDatabaseHealth();

  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    database: dbHealth,
    websocket: wsService ? 'enabled' : 'disabled',
  });
});

// API root
apiRouter.get('/', (_req: Request, res: Response) => {
  res.json({
    name: 'LiveLingo Backend API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      languages: '/api/languages',
      translate: '/api/translate',
      stats: '/api/stats',
      websocket: wsService ? 'ws://localhost:' + PORT + '/ws' : 'disabled',
    },
  });
});

// Languages endpoint (fallback if geminiService not available)
apiRouter.get('/languages', (_req: Request, res: Response) => {
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

// Stats endpoint
apiRouter.get('/stats', (_req: Request, res: Response) => {
  res.json({
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    platform: process.platform,
    nodeVersion: process.version,
  });
});

// Translate endpoint (requires geminiService)
apiRouter.post('/translate', async (req: Request, res: Response) => {
  const { text, targetLanguage, sourceLanguage } = req.body;

  if (!text || !targetLanguage) {
    res.status(400).json({
      error: 'Missing required fields: text, targetLanguage',
    });
    return;
  }

  if (!geminiService) {
    res.status(503).json({
      error: 'Translation service not available',
      message: 'GEMINI_API_KEY not configured',
    });
    return;
  }

  try {
    const result = await geminiService.translateText(text, targetLanguage, sourceLanguage);
    res.json(result);
  } catch (error) {
    console.error('Translation error:', error);
    res.status(500).json({
      error: 'Translation failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

app.use('/api', apiRouter);

// Error handling middleware
app.use((err: Error, _req: Request, res: Response, _next: express.NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not found',
    message: 'The requested resource was not found',
  });
});

// Start server
async function startServer() {
  try {
    // Check database connection
    const dbConnected = await checkDatabaseConnection();

    if (!dbConnected) {
      console.error('❌ Failed to connect to database');
      process.exit(1);
    }

    console.log('✅ Database connected successfully');

    server.listen(PORT, () => {
      console.log('='.repeat(60));
      console.log('🚀 LiveLingo Backend Server');
      console.log('='.repeat(60));
      console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`HTTP Server: http://localhost:${PORT}`);
      console.log(`WebSocket Server: ${wsService ? `ws://localhost:${PORT}/ws` : 'Disabled'}`);
      console.log(`API Endpoints: http://localhost:${PORT}/api`);
      console.log(`Health Check: http://localhost:${PORT}/api/health`);
      console.log('='.repeat(60));
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  if (wsService) {
    wsService.shutdown();
  }
  await prisma.$disconnect();
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, closing server...');
  if (wsService) {
    wsService.shutdown();
  }
  await prisma.$disconnect();
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

startServer();
