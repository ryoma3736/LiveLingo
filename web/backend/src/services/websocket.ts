import { WebSocketServer, WebSocket } from 'ws';
import { Server } from 'http';
import { v4 as uuidv4 } from 'uuid';
import type { ExtendedWebSocket, ClientMessage, ServerMessage, SessionConfig } from '../types';
import { GeminiService } from './gemini';

export class WebSocketService {
  private wss: WebSocketServer;
  private clients: Map<string, ExtendedWebSocket>;
  private geminiService: GeminiService;
  private heartbeatInterval: NodeJS.Timeout | null = null;

  constructor(server: Server, geminiApiKey: string) {
    this.wss = new WebSocketServer({
      server,
      path: '/ws',
      maxPayload: parseInt(process.env.WS_MAX_PAYLOAD_SIZE || '10485760', 10), // 10MB default
    });
    this.clients = new Map();
    this.geminiService = new GeminiService(geminiApiKey);

    this.initialize();
  }

  private initialize(): void {
    this.wss.on('connection', (ws: WebSocket) => {
      this.handleConnection(ws as ExtendedWebSocket);
    });

    // Start heartbeat
    this.startHeartbeat();

    console.log('WebSocket server initialized');
  }

  private handleConnection(ws: ExtendedWebSocket): void {
    const clientId = uuidv4();
    ws.id = clientId;
    ws.isAlive = true;
    ws.sessionConfig = {
      enableTranscription: true,
      enableTranslation: false,
    };

    this.clients.set(clientId, ws);
    console.log(`Client connected: ${clientId} (Total clients: ${this.clients.size})`);

    // Send welcome message
    this.sendMessage(ws, {
      type: 'status',
      data: {
        message: 'Connected to LiveLingo server',
        clientId,
      },
      timestamp: Date.now(),
    });

    // Handle pong
    ws.on('pong', () => {
      ws.isAlive = true;
    });

    // Handle messages
    ws.on('message', async (data: Buffer) => {
      try {
        const message: ClientMessage = JSON.parse(data.toString());
        await this.handleMessage(ws, message);
      } catch (error) {
        console.error('Message handling error:', error);
        this.sendError(ws, 'Invalid message format');
      }
    });

    // Handle disconnection
    ws.on('close', () => {
      this.clients.delete(clientId);
      console.log(`Client disconnected: ${clientId} (Total clients: ${this.clients.size})`);
    });

    // Handle errors
    ws.on('error', (error) => {
      console.error(`WebSocket error for client ${clientId}:`, error);
    });
  }

  private async handleMessage(ws: ExtendedWebSocket, message: ClientMessage): Promise<void> {
    switch (message.type) {
      case 'ping':
        this.sendMessage(ws, {
          type: 'pong',
          timestamp: Date.now(),
        });
        break;

      case 'config':
        this.handleConfig(ws, message.data);
        break;

      case 'audio':
        await this.handleAudio(ws, message.data);
        break;

      case 'text':
        await this.handleText(ws, message.data);
        break;

      default:
        this.sendError(ws, `Unknown message type: ${message.type}`);
    }
  }

  private handleConfig(ws: ExtendedWebSocket, config: SessionConfig): void {
    ws.sessionConfig = { ...ws.sessionConfig, ...config };
    console.log(`Config updated for client ${ws.id}:`, ws.sessionConfig);

    this.sendMessage(ws, {
      type: 'status',
      data: {
        message: 'Configuration updated',
        config: ws.sessionConfig,
      },
      timestamp: Date.now(),
    });
  }

  private async handleAudio(ws: ExtendedWebSocket, audioData: any): Promise<void> {
    try {
      const config = ws.sessionConfig!;
      const audioChunk = {
        audio: audioData.audio,
        format: audioData.format || 'webm',
        sampleRate: audioData.sampleRate,
      };

      if (config.enableTranscription && config.enableTranslation && config.targetLanguage) {
        // Transcribe and translate
        const result = await this.geminiService.transcribeAndTranslate(
          audioChunk,
          config.targetLanguage,
          config.sourceLanguage
        );

        // Send transcription
        this.sendMessage(ws, {
          type: 'transcription',
          data: result.transcription,
          timestamp: Date.now(),
        });

        // Send translation
        this.sendMessage(ws, {
          type: 'translation',
          data: result.translation,
          timestamp: Date.now(),
        });
      } else if (config.enableTranscription) {
        // Only transcribe
        const transcription = await this.geminiService.transcribeAudio(
          audioChunk,
          config.sourceLanguage
        );

        this.sendMessage(ws, {
          type: 'transcription',
          data: transcription,
          timestamp: Date.now(),
        });
      }
    } catch (error) {
      console.error('Audio processing error:', error);
      this.sendError(ws, `Audio processing failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private async handleText(ws: ExtendedWebSocket, textData: any): Promise<void> {
    try {
      const config = ws.sessionConfig!;

      if (config.enableTranslation && config.targetLanguage) {
        const translation = await this.geminiService.translateText(
          textData.text,
          config.targetLanguage,
          config.sourceLanguage
        );

        this.sendMessage(ws, {
          type: 'translation',
          data: translation,
          timestamp: Date.now(),
        });
      }
    } catch (error) {
      console.error('Text processing error:', error);
      this.sendError(ws, `Text processing failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  private sendMessage(ws: ExtendedWebSocket, message: ServerMessage): void {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify(message));
    }
  }

  private sendError(ws: ExtendedWebSocket, errorMessage: string): void {
    this.sendMessage(ws, {
      type: 'error',
      data: { error: errorMessage },
      timestamp: Date.now(),
    });
  }

  private startHeartbeat(): void {
    const interval = parseInt(process.env.WS_HEARTBEAT_INTERVAL || '30000', 10);

    this.heartbeatInterval = setInterval(() => {
      this.clients.forEach((ws) => {
        if (!ws.isAlive) {
          console.log(`Terminating inactive client: ${ws.id}`);
          ws.terminate();
          this.clients.delete(ws.id);
          return;
        }

        ws.isAlive = false;
        ws.ping();
      });
    }, interval);

    console.log(`Heartbeat started with ${interval}ms interval`);
  }

  public shutdown(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    this.clients.forEach((ws) => {
      ws.close(1000, 'Server shutting down');
    });

    this.wss.close();
    console.log('WebSocket server shut down');
  }
}
