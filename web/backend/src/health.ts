import { Request, Response } from 'express';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * Health check endpoint for Docker healthcheck
 * Verifies database connection and application status
 */
export async function healthCheck(req: Request, res: Response): Promise<void> {
  try {
    // Check database connection
    await prisma.$queryRaw`SELECT 1`;

    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'livelingo-backend',
      database: 'connected',
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      service: 'livelingo-backend',
      database: 'disconnected',
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

/**
 * Readiness check endpoint
 * Checks if the service is ready to accept traffic
 */
export async function readinessCheck(req: Request, res: Response): Promise<void> {
  try {
    // Check database connection
    await prisma.$queryRaw`SELECT 1`;

    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
}

/**
 * Liveness check endpoint
 * Simple check to verify the process is running
 */
export function livenessCheck(req: Request, res: Response): void {
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
  });
}
