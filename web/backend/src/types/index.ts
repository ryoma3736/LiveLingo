import { WebSocket } from 'ws';

export interface ClientMessage {
  type: 'audio' | 'text' | 'config' | 'ping';
  data?: any;
  timestamp?: number;
}

export interface ServerMessage {
  type: 'transcription' | 'translation' | 'error' | 'pong' | 'status';
  data?: any;
  timestamp: number;
}

export interface AudioChunk {
  audio: string; // Base64 encoded audio
  format?: 'webm' | 'wav' | 'mp3';
  sampleRate?: number;
}

export interface TranscriptionResult {
  text: string;
  language: string;
  confidence?: number;
}

export interface TranslationResult {
  originalText: string;
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  confidence?: number;
}

export interface SessionConfig {
  sourceLanguage?: string;
  targetLanguage?: string;
  enableTranscription?: boolean;
  enableTranslation?: boolean;
}

export interface ExtendedWebSocket extends WebSocket {
  id: string;
  isAlive: boolean;
  sessionConfig?: SessionConfig;
}

export interface GeminiStreamResponse {
  text?: string;
  audio?: Buffer;
  done: boolean;
}
