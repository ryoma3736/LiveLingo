import WebSocket from 'ws';

interface GeminiConfig {
  apiKey: string;
  model?: string;
}

interface AudioChunk {
  audio: string;
  format?: string;
  sampleRate?: number;
}

interface TranscriptionResult {
  text: string;
  confidence: number;
  language?: string;
}

interface TranslationResult {
  originalText: string;
  translatedText: string;
  targetLanguage: string;
  sourceLanguage?: string;
}

/**
 * REST-based Gemini Service for simple operations
 */
export class GeminiService {
  private apiKey: string;
  private baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async translateText(
    text: string,
    targetLanguage: string,
    sourceLanguage?: string
  ): Promise<TranslationResult> {
    const prompt = sourceLanguage
      ? `Translate the following text from ${sourceLanguage} to ${targetLanguage}. Only respond with the translation, nothing else:\n\n${text}`
      : `Translate the following text to ${targetLanguage}. Only respond with the translation, nothing else:\n\n${text}`;

    try {
      const response = await fetch(
        `${this.baseUrl}/models/gemini-2.0-flash-exp:generateContent?key=${this.apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }]
          })
        }
      );

      const data = await response.json() as {
        candidates?: Array<{
          content?: {
            parts?: Array<{ text?: string }>
          }
        }>
      };
      const translatedText = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

      return {
        originalText: text,
        translatedText: translatedText.trim(),
        targetLanguage,
        sourceLanguage
      };
    } catch (error) {
      console.error('Translation error:', error);
      throw error;
    }
  }

  async transcribeAudio(
    audioChunk: AudioChunk,
    language?: string
  ): Promise<TranscriptionResult> {
    // For now, return a placeholder since audio transcription requires different handling
    return {
      text: '[Audio transcription not yet implemented]',
      confidence: 0,
      language
    };
  }

  async transcribeAndTranslate(
    audioChunk: AudioChunk,
    targetLanguage: string,
    sourceLanguage?: string
  ): Promise<{ transcription: TranscriptionResult; translation: TranslationResult }> {
    const transcription = await this.transcribeAudio(audioChunk, sourceLanguage);
    const translation = await this.translateText(
      transcription.text,
      targetLanguage,
      sourceLanguage
    );

    return { transcription, translation };
  }
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
