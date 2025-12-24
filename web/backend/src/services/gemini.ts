import WebSocket from 'ws';

interface GeminiConfig {
  apiKey: string;
  model?: string;
}

interface TranslationMode {
  sourceLanguage: string;
  targetLanguage: string;
  bidirectional: boolean;
}

export class GeminiLiveService {
  private ws: WebSocket | null = null;
  private config: GeminiConfig;
  private isConnected = false;

  constructor(config: GeminiConfig) {
    this.config = {
      ...config,
      model: config.model || 'models/gemini-2.0-flash-exp'
    };
  }

  async connect(translationMode: TranslationMode): Promise<void> {
    const wsUrl = `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=${this.config.apiKey}`;

    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(wsUrl);

      this.ws.on('open', () => {
        console.log('[GeminiLive] Connected');
        this.isConnected = true;
        this.sendSetupMessage(translationMode);
        resolve();
      });

      this.ws.on('error', (error) => {
        console.error('[GeminiLive] Error:', error);
        reject(error);
      });

      this.ws.on('close', () => {
        console.log('[GeminiLive] Disconnected');
        this.isConnected = false;
      });
    });
  }

  private sendSetupMessage(mode: TranslationMode): void {
    const systemInstruction = mode.bidirectional
      ? `You are a real-time interpreter. Translate speech between ${mode.sourceLanguage} and ${mode.targetLanguage}. Detect the input language and translate to the other. Respond only with the translation.`
      : `Translate all speech from ${mode.sourceLanguage} to ${mode.targetLanguage}. Respond only with the translation.`;

    const setup = {
      setup: {
        model: this.config.model,
        generation_config: {
          response_modalities: ['AUDIO', 'TEXT'],
          speech_config: {
            voice_config: {
              prebuilt_voice_config: {
                voice_name: 'Aoede'
              }
            }
          }
        },
        system_instruction: {
          parts: [{ text: systemInstruction }]
        }
      }
    };

    this.ws?.send(JSON.stringify(setup));
  }

  sendAudio(audioData: Buffer): void {
    if (!this.isConnected || !this.ws) return;

    const message = {
      realtime_input: {
        media_chunks: [{
          mime_type: 'audio/pcm;rate=16000',
          data: audioData.toString('base64')
        }]
      }
    };

    this.ws.send(JSON.stringify(message));
  }

  sendText(text: string): void {
    if (!this.isConnected || !this.ws) return;

    const message = {
      client_content: {
        turns: [{
          role: 'user',
          parts: [{ text }]
        }],
        turn_complete: true
      }
    };

    this.ws.send(JSON.stringify(message));
  }

  onMessage(callback: (data: any) => void): void {
    this.ws?.on('message', (data) => {
      try {
        const parsed = JSON.parse(data.toString());
        callback(parsed);
      } catch (e) {
        console.error('[GeminiLive] Parse error:', e);
      }
    });
  }

  disconnect(): void {
    this.ws?.close();
    this.ws = null;
    this.isConnected = false;
  }
}

export default GeminiLiveService;
