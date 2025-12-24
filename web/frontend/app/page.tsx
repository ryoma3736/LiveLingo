'use client'

import { useState, useEffect, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { io, Socket } from 'socket.io-client'

interface TranslationMessage {
  original: string
  translated: string
  sourceLang: string
  targetLang: string
  timestamp: string
}

const SUPPORTED_LANGUAGES = [
  { code: 'en', name: 'English', native: 'English' },
  { code: 'ja', name: 'Japanese', native: '日本語' },
  { code: 'es', name: 'Spanish', native: 'Español' },
  { code: 'fr', name: 'French', native: 'Français' },
  { code: 'de', name: 'German', native: 'Deutsch' },
  { code: 'zh', name: 'Chinese', native: '中文' },
  { code: 'ko', name: 'Korean', native: '한국어' },
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
    })

    socketRef.current.on('disconnect', () => {
      setIsConnected(false)
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

        stream.getTracks().forEach((track) => track.stop())
      }

      mediaRecorder.start()
      setIsRecording(true)
    } catch (error) {
      console.error('Error starting recording:', error)
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
    <div className="min-h-screen flex flex-col items-center px-5 py-16 md:py-24">
      {/* Header - Frosted glass with status */}
      <motion.header
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
        className="w-full max-w-container-md mb-20"
      >
        <div className="glass-strong rounded-apple-xl p-8 text-center">
          <h1 className="text-6xl md:text-7xl font-extralight tracking-tighter text-primary mb-3">
            LiveLingo
          </h1>
          <p className="text-lg md:text-xl font-light text-secondary">
            Real-time speech translation
          </p>

          {/* Status indicator */}
          <div className="mt-6 flex items-center justify-center gap-2">
            <div className={`status-indicator ${isConnected ? 'connected' : 'disconnected'}`} />
            <span className="text-sm font-medium text-secondary">
              {isConnected ? 'Connected' : 'Connecting...'}
            </span>
          </div>
        </div>
      </motion.header>

      {/* Language Selector - Floating pills */}
      <motion.section
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
        className="w-full max-w-container-md mb-16"
      >
        <div className="glass rounded-apple-xl p-8">
          <h2 className="text-2xl font-semibold text-primary mb-6 text-center tracking-tight">
            Languages
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {/* Source Language */}
            <div>
              <label className="block text-sm font-medium text-secondary mb-3">From</label>
              <div className="flex flex-wrap gap-2">
                {SUPPORTED_LANGUAGES.map((lang) => (
                  <button
                    key={`source-${lang.code}`}
                    onClick={() => !isRecording && setSourceLang(lang.code)}
                    disabled={isRecording}
                    className={`language-pill ${sourceLang === lang.code ? 'active' : ''}`}
                    aria-label={`Select ${lang.name} as source language`}
                  >
                    {lang.native}
                  </button>
                ))}
              </div>
            </div>

            {/* Target Language */}
            <div>
              <label className="block text-sm font-medium text-secondary mb-3">To</label>
              <div className="flex flex-wrap gap-2">
                {SUPPORTED_LANGUAGES.map((lang) => (
                  <button
                    key={`target-${lang.code}`}
                    onClick={() => !isRecording && setTargetLang(lang.code)}
                    disabled={isRecording}
                    className={`language-pill ${targetLang === lang.code ? 'active' : ''}`}
                    aria-label={`Select ${lang.name} as target language`}
                  >
                    {lang.native}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </motion.section>

      {/* Recording Button - Hero element */}
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.6, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
        className="mb-16"
      >
        <button
          onClick={toggleRecording}
          disabled={!isConnected}
          className={`recording-button ${isRecording ? 'recording' : ''}`}
          aria-label={isRecording ? 'Stop recording' : 'Start recording'}
        >
          <div className="flex flex-col items-center justify-center text-white">
            <AnimatePresence mode="wait">
              {isRecording ? (
                <motion.div
                  key="stop"
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.8 }}
                  transition={{ duration: 0.2 }}
                  className="flex flex-col items-center"
                >
                  <svg
                    className="w-12 h-12 mb-2"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <rect x="6" y="6" width="12" height="12" strokeWidth="2" />
                  </svg>
                  <span className="text-sm font-semibold">Stop</span>
                </motion.div>
              ) : (
                <motion.div
                  key="record"
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.8 }}
                  transition={{ duration: 0.2 }}
                  className="flex flex-col items-center"
                >
                  <svg
                    className="w-12 h-12 mb-2"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                    aria-hidden="true"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="2"
                      d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"
                    />
                  </svg>
                  <span className="text-sm font-semibold">Record</span>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </button>
      </motion.div>

      {/* Current Transcription - Live feedback */}
      <AnimatePresence>
        {currentText && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.3 }}
            className="w-full max-w-container-md mb-12"
          >
            <div className="translation-card border-l-4 border-accent-500">
              <div className="flex items-center gap-2 mb-3">
                <div className="w-2 h-2 bg-accent-500 rounded-full animate-pulse-subtle" />
                <span className="text-sm font-medium text-secondary">Transcribing...</span>
              </div>
              <p className="text-lg text-primary font-light">{currentText}</p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Translation History - Staggered animation */}
      <motion.section
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.6, delay: 0.3 }}
        className="w-full max-w-container-md"
      >
        <h2 className="text-3xl font-semibold text-primary mb-8 text-center tracking-tight">
          History
        </h2>

        <div className="space-y-4">
          <AnimatePresence mode="popLayout">
            {translations.length === 0 ? (
              <motion.div
                key="empty"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="translation-card text-center py-12"
              >
                <p className="text-secondary font-light">
                  Tap the microphone to start translating
                </p>
              </motion.div>
            ) : (
              translations.map((translation, index) => (
                <motion.div
                  key={`${translation.timestamp}-${index}`}
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  transition={{
                    duration: 0.4,
                    delay: index * 0.05,
                    ease: [0.16, 1, 0.3, 1],
                  }}
                  layout
                >
                  <div className="translation-card">
                    {/* Header */}
                    <div className="flex justify-between items-center mb-4">
                      <div className="flex gap-2 text-sm">
                        <span className="px-3 py-1 rounded-full bg-accent-100 dark:bg-accent-900/30 text-accent-700 dark:text-accent-400 font-medium">
                          {translation.sourceLang.toUpperCase()}
                        </span>
                        <span className="text-tertiary">→</span>
                        <span className="px-3 py-1 rounded-full bg-success/10 text-success font-medium">
                          {translation.targetLang.toUpperCase()}
                        </span>
                      </div>
                      <span className="text-xs text-tertiary">
                        {new Date(translation.timestamp).toLocaleTimeString([], {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </span>
                    </div>

                    {/* Content */}
                    <div className="space-y-4">
                      <div>
                        <p className="text-xs font-medium text-tertiary mb-1.5 uppercase tracking-wide">
                          Original
                        </p>
                        <p className="text-base text-secondary font-light leading-relaxed">
                          {translation.original}
                        </p>
                      </div>

                      <div className="divider" />

                      <div>
                        <p className="text-xs font-medium text-tertiary mb-1.5 uppercase tracking-wide">
                          Translation
                        </p>
                        <p className="text-lg text-primary font-normal leading-relaxed">
                          {translation.translated}
                        </p>
                      </div>
                    </div>
                  </div>
                </motion.div>
              ))
            )}
          </AnimatePresence>
        </div>
      </motion.section>

      {/* Footer spacer */}
      <div className="h-24" />
    </div>
  )
}
