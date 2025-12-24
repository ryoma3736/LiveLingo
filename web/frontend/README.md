# LiveLingo Frontend

Real-time speech translation web application powered by Next.js 14 and Gemini AI.

## Features

- Real-time audio recording and streaming
- WebSocket-based communication with backend
- Multi-language support (English, Japanese, Spanish, French, German, Chinese, Korean)
- Live transcription display
- Translation history with timestamps
- Responsive design with Tailwind CSS
- Dark mode support

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Real-time Communication**: Socket.IO Client
- **Audio**: Web Audio API / MediaRecorder API

## Getting Started

### Prerequisites

- Node.js 18+ installed
- LiveLingo backend running (see `/Users/satoryouma/genie_0.1/LiveLingo/web/backend`)

### Installation

```bash
# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Edit .env and set your backend URL
# NEXT_PUBLIC_BACKEND_URL=http://localhost:8000
```

### Development

```bash
# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Production Build

```bash
# Build for production
npm run build

# Start production server
npm start
```

## Project Structure

```
web/frontend/
├── app/
│   ├── layout.tsx          # Root layout with metadata
│   ├── page.tsx            # Main translation interface
│   └── globals.css         # Global styles with Tailwind
├── public/                 # Static assets
├── package.json           # Dependencies and scripts
├── next.config.js         # Next.js configuration
├── tailwind.config.ts     # Tailwind CSS configuration
└── tsconfig.json          # TypeScript configuration
```

## Key Components

### Recording Control
- Large circular button for start/stop recording
- Visual feedback with pulsing animation during recording
- Microphone permission handling

### Language Selector
- Dropdown menus for source and target languages
- Supports 7 major languages
- Disabled during active recording

### Translation Display
- Real-time transcription preview
- Translation history cards with timestamps
- Language pair indicators
- Original and translated text side-by-side

## Socket.IO Events

### Client → Server
- `audio_stream`: Send audio data with language settings

### Server → Client
- `transcription`: Receive live transcription updates
- `translation`: Receive completed translations
- `error`: Handle translation errors

## Browser Compatibility

- Chrome 90+ (recommended)
- Firefox 88+
- Safari 14+
- Edge 90+

**Note**: Requires browser support for MediaRecorder API and WebSocket.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_BACKEND_URL` | Backend WebSocket URL | `http://localhost:8000` |

## Troubleshooting

### Microphone not working
1. Check browser permissions
2. Ensure HTTPS in production (required for getUserMedia)
3. Verify microphone is not used by another application

### Connection issues
1. Verify backend is running on configured URL
2. Check CORS settings in backend
3. Inspect browser console for WebSocket errors

### Translation delays
1. Check network latency
2. Verify Gemini API key is valid in backend
3. Ensure backend has sufficient resources

## License

MIT
