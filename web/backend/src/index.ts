import express, { Request, Response } from 'express';
import { createServer } from 'http';
import cors from 'cors';
import dotenv from 'dotenv';
import { prisma, checkDatabaseConnection, getDatabaseHealth } from './lib/prisma';
import { createApiRouter } from './routes/api';
import { WebSocketService } from './services/websocket';

// Load environment variables
dotenv.config();

const app = express();
const server = createServer(app);
const PORT = process.env.PORT || 3001;

// CORS configuration
const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [
  'http://localhost:3000',
  'http://localhost:5173',
];

// Middleware
app.use(cors({
  origin: allowedOrigins,
  credentials: true,
}));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Initialize WebSocket service if Gemini API key is provided
let wsService: WebSocketService | null = null;
if (process.env.GEMINI_API_KEY) {
  wsService = new WebSocketService(server, process.env.GEMINI_API_KEY);
  console.log('✅ WebSocket service initialized');
} else {
  console.warn('⚠️  GEMINI_API_KEY not found - WebSocket features disabled');
}

// API Routes
const apiRouter = express.Router();

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
      users: '/api/users (coming soon)',
      conversations: '/api/conversations (coming soon)',
      transcripts: '/api/transcripts (coming soon)',
      websocket: wsService ? 'ws://localhost:' + PORT + '/ws' : 'disabled',
    },
  });
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
