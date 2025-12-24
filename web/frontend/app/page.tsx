'use client'

import { useState, useEffect, useRef } from 'react'
import { io, Socket } from 'socket.io-client'

interface TranslationMessage {
  original: string
  translated: string
  sourceLang: string
  targetLang: string
  timestamp: string
}

const SUPPORTED_LANGUAGES = [
  { code: 'en', name: 'English' },
  { code: 'ja', name: '日本語' },
  { code: 'es', name: 'Español' },
  { code: 'fr', name: 'Français' },
  { code: 'de', name: 'Deutsch' },
  { code: 'zh', name: '中文' },
  { code: 'ko', name: '한국어' },
]

export default function Home() {
  const [isRecording, setIsRecording] = useState(false)
  const [isConnected, setIsConnected] = useState(false)
  const [sourceLang, setSourceLang] = useState('en')
  const [targetLang, setTargetLang] = useState('ja')
  const [translations, setTranslations] = useState<TranslationMessage[]>([])
  const [currentText, setCurrentText] = useState('')

  const socketRef = useRef<Socket | null>(null)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const audioChunksRef = useRef<Blob[]>([])

  // Socket.IO connection
  useEffect(() => {
    const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:8000'
    socketRef.current = io(backendUrl)

    socketRef.current.on('connect', () => {
      setIsConnected(true)
      console.log('Connected to server')
    })

    socketRef.current.on('disconnect', () => {
      setIsConnected(false)
      console.log('Disconnected from server')
    })

    socketRef.current.on('transcription', (data: { text: string }) => {
      setCurrentText(data.text)
    })

    socketRef.current.on('translation', (data: TranslationMessage) => {
      setTranslations((prev) => [data, ...prev])
      setCurrentText('')
    })

    socketRef.current.on('error', (error: { message: string }) => {
      console.error('Translation error:', error.message)
      alert(`Error: ${error.message}`)
    })

    return () => {
      if (socketRef.current) {
        socketRef.current.disconnect()
      }
    }
  }, [])

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mediaRecorder = new MediaRecorder(stream, {
        mimeType: 'audio/webm;codecs=opus',
      })

      mediaRecorderRef.current = mediaRecorder
      audioChunksRef.current = []

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data)
        }
      }

      mediaRecorder.onstop = async () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/webm' })

        // Convert blob to base64
        const reader = new FileReader()
        reader.readAsDataURL(audioBlob)
        reader.onloadend = () => {
          const base64Audio = reader.result as string

          if (socketRef.current) {
            socketRef.current.emit('audio_stream', {
              audio: base64Audio.split(',')[1],
              sourceLang,
              targetLang,
            })
          }
        }

        // Stop all audio tracks
        stream.getTracks().forEach(track => track.stop())
      }

      mediaRecorder.start()
      setIsRecording(true)
    } catch (error) {
      console.error('Error starting recording:', error)
      alert('Failed to access microphone. Please check permissions.')
    }
  }

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop()
      setIsRecording(false)
    }
  }

  const toggleRecording = () => {
    if (isRecording) {
      stopRecording()
    } else {
      startRecording()
    }
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      {/* Header */}
      <header className="text-center mb-12">
        <h1 className="text-5xl font-bold text-gray-800 dark:text-white mb-4">
          LiveLingo
        </h1>
        <p className="text-xl text-gray-600 dark:text-gray-300">
          Real-time Speech Translation powered by Gemini AI
        </p>
        <div className="mt-4 flex items-center justify-center gap-2">
          <div
            className={`w-3 h-3 rounded-full ${
              isConnected ? 'bg-green-500' : 'bg-red-500'
            }`}
          />
          <span className="text-sm text-gray-600 dark:text-gray-400">
            {isConnected ? 'Connected' : 'Disconnected'}
          </span>
        </div>
      </header>

      {/* Language Selector */}
      <div className="translation-card mb-8">
        <h2 className="text-2xl font-semibold mb-4 text-gray-800 dark:text-white">
          Language Settings
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Source Language
            </label>
            <select
              value={sourceLang}
              onChange={(e) => setSourceLang(e.target.value)}
              className="language-selector w-full"
              disabled={isRecording}
            >
              {SUPPORTED_LANGUAGES.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Target Language
            </label>
            <select
              value={targetLang}
              onChange={(e) => setTargetLang(e.target.value)}
              className="language-selector w-full"
              disabled={isRecording}
            >
              {SUPPORTED_LANGUAGES.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Recording Control */}
      <div className="flex justify-center mb-8">
        <button
          onClick={toggleRecording}
          disabled={!isConnected}
          className={`relative w-32 h-32 rounded-full shadow-2xl transition-all duration-300 transform hover:scale-110 active:scale-95 ${
            isRecording
              ? 'bg-red-500 recording-animation'
              : 'bg-primary-500 hover:bg-primary-600'
          } ${!isConnected ? 'opacity-50 cursor-not-allowed' : ''}`}
        >
          <div className="flex flex-col items-center justify-center text-white">
            {isRecording ? (
              <>
                <svg
                  className="w-12 h-12 mb-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <rect x="6" y="6" width="12" height="12" strokeWidth="2" />
                </svg>
                <span className="text-sm font-semibold">Stop</span>
              </>
            ) : (
              <>
                <svg
                  className="w-12 h-12 mb-2"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
                  />
                </svg>
                <span className="text-sm font-semibold">Record</span>
              </>
            )}
          </div>
        </button>
      </div>

      {/* Current Transcription */}
      {currentText && (
        <div className="translation-card mb-8 border-l-4 border-primary-500">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-2 h-2 bg-primary-500 rounded-full animate-pulse" />
            <span className="text-sm font-medium text-gray-600 dark:text-gray-400">
              Transcribing...
            </span>
          </div>
          <p className="text-lg text-gray-800 dark:text-white">{currentText}</p>
        </div>
      )}

      {/* Translation History */}
      <div className="space-y-4">
        <h2 className="text-2xl font-semibold text-gray-800 dark:text-white mb-4">
          Translation History
        </h2>
        {translations.length === 0 ? (
          <div className="translation-card text-center text-gray-500 dark:text-gray-400">
            <p>No translations yet. Click the microphone to start!</p>
          </div>
        ) : (
          translations.map((translation, index) => (
            <div key={index} className="translation-card hover:shadow-xl">
              <div className="flex justify-between items-start mb-3">
                <div className="flex gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <span className="px-2 py-1 bg-blue-100 dark:bg-blue-900 rounded">
                    {translation.sourceLang}
                  </span>
                  <span>→</span>
                  <span className="px-2 py-1 bg-green-100 dark:bg-green-900 rounded">
                    {translation.targetLang}
                  </span>
                </div>
                <span className="text-xs text-gray-500">
                  {new Date(translation.timestamp).toLocaleTimeString()}
                </span>
              </div>
              <div className="space-y-3">
                <div>
                  <p className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">
                    Original
                  </p>
                  <p className="text-gray-800 dark:text-white">
                    {translation.original}
                  </p>
                </div>
                <div className="border-t border-gray-200 dark:border-gray-700 pt-3">
                  <p className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-1">
                    Translation
                  </p>
                  <p className="text-lg font-medium text-primary-600 dark:text-primary-400">
                    {translation.translated}
                  </p>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
